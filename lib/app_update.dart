import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppRelease {
  final String version, sha256, notes;
  final int build, bytes;
  final bool required;
  final Uri download;
  const AppRelease(
      {required this.version,
      required this.sha256,
      required this.notes,
      required this.build,
      required this.bytes,
      required this.required,
      required this.download});

  factory AppRelease.fromJson(Map<String, dynamic> data) {
    final build = int.tryParse((data['build_number'] ?? '').toString()) ?? 0;
    final bytes = int.tryParse((data['bytes'] ?? '').toString()) ?? 0;
    final hash = (data['sha256'] ?? '').toString().toLowerCase();
    final url = Uri.tryParse((data['download_url'] ?? '').toString());
    if (build < 1 ||
        bytes < 10000 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty) {
      throw const FormatException('Invalid app update information.');
    }
    return AppRelease(
        version: (data['version'] ?? '').toString(),
        sha256: hash,
        notes: (data['notes'] ?? '').toString(),
        build: build,
        bytes: bytes,
        required: data['required_update'] == true,
        download: url);
  }

  /// The GitHub Actions workflow publishes this snapshot only after the
  /// signed APK is public. It is used when the panel cannot be reached.
  factory AppRelease.fromGithubSnapshot(Map<String, dynamic> data) {
    final tag = RegExp(r'^v([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)$')
        .firstMatch((data['tag_name'] ?? '').toString());
    final policy = RegExp(r'^<!-- jm-app-update:required=(true|false) -->')
        .firstMatch((data['body'] ?? '').toString());
    final assets = data['assets'];
    if (data['draft'] != false ||
        data['prerelease'] != false ||
        tag == null ||
        policy == null ||
        assets is! List ||
        assets.length != 1 ||
        assets.first is! Map<String, dynamic>) {
      throw const FormatException('Invalid official GitHub release.');
    }
    final asset = assets.first as Map<String, dynamic>;
    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    if (asset['name'] != 'jm-broadband.apk' ||
        asset['state'] != 'uploaded' ||
        url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        url.userInfo.isNotEmpty ||
        url.port != 443 ||
        !url.path.startsWith(
            '/mahin-wpdev/jm-broadband-android/releases/download/') ||
        url.pathSegments.last != 'jm-broadband.apk' ||
        url.pathSegments.length < 2 ||
        url.pathSegments[url.pathSegments.length - 2] != tag.group(0)) {
      throw const FormatException('Invalid official GitHub APK asset.');
    }
    final digest = (asset['digest'] ?? '').toString();
    if (!RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('Invalid official APK digest.');
    }
    return AppRelease.fromJson({
      'version': tag.group(1),
      'build_number': int.parse(tag.group(2)!),
      'bytes': asset['size'],
      'sha256': digest.substring(7),
      'required_update': policy.group(1) == 'true',
      'download_url': url.toString(),
      'notes':
          (data['body'] as String).substring(policy.group(0)!.length).trim(),
    });
  }
}

class _PanelUpdateUnavailable implements Exception {
  const _PanelUpdateUnavailable();
}

class AppUpdater {
  static Uri manifest(Uri apiEndpoint) {
    final path = apiEndpoint.path
        .replaceFirst(RegExp(r'/mobile-api\.php$'), '/mobile-app-version.php');
    return apiEndpoint.replace(path: path, query: null, fragment: null);
  }

  static bool _sameOrigin(Uri a, Uri b) =>
      a.scheme == b.scheme && a.host == b.host && a.port == b.port;

  /// Panel redirect -> official project release -> GitHub release asset CDN.
  /// An APK still has to match GitHub's advertised SHA-256 and exact byte count.
  static bool trustedDownloadRedirect(Uri uri, Uri panelUrl) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) return false;
    if (_sameOrigin(uri, panelUrl)) return true;
    if (uri.host == 'github.com' && uri.port == 443) {
      return uri.path
          .startsWith('/mahin-wpdev/jm-broadband-android/releases/download/');
    }
    return uri.port == 443 &&
        (uri.host == 'release-assets.githubusercontent.com' ||
            uri.host == 'objects.githubusercontent.com');
  }

  static final Uri officialManifest =
      Uri.parse('https://raw.githubusercontent.com/mahin-wpdev/'
          'jm-broadband-android/main/mobile-release.json');

  static Future<AppRelease> _officialRelease(http.Client client) async {
    final request = http.Request('GET', officialManifest)
      ..followRedirects = false;
    final stream =
        await client.send(request).timeout(const Duration(seconds: 12));
    final response = await http.Response.fromStream(stream)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 || response.bodyBytes.length > 1048576) {
      throw StateError('Official GitHub release manifest unavailable.');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid GitHub release JSON.');
    }
    return AppRelease.fromGithubSnapshot(data);
  }

  static Future<AppRelease?> check(Uri apiEndpoint) async {
    final uri = manifest(apiEndpoint);
    if (uri.scheme != 'https') throw const FormatException('HTTPS required.');
    final client = http.Client();
    try {
      late final AppRelease release;
      try {
        final request = http.Request('GET', uri)..followRedirects = false;
        final stream =
            await client.send(request).timeout(const Duration(seconds: 5));
        final response = await http.Response.fromStream(stream)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 404 ||
            response.statusCode == 429 ||
            response.statusCode >= 500) {
          throw const _PanelUpdateUnavailable();
        }
        if (response.statusCode != 200) {
          throw StateError('Update server unavailable.');
        }
        final raw = jsonDecode(response.body);
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid panel release JSON.');
        }
        release = AppRelease.fromJson(raw);
        if (!_sameOrigin(release.download, uri)) {
          throw const FormatException('Update server origin mismatch.');
        }
      } on SocketException {
        release = await _officialRelease(client);
      } on http.ClientException {
        release = await _officialRelease(client);
      } on HandshakeException {
        release = await _officialRelease(client);
      } on TimeoutException {
        release = await _officialRelease(client);
      } on _PanelUpdateUnavailable {
        release = await _officialRelease(client);
      }
      final info = await PackageInfo.fromPlatform();
      final installed = int.tryParse(info.buildNumber) ?? 0;
      return release.build > installed ? release : null;
    } finally {
      client.close();
    }
  }

  static Future<File> download(
      AppRelease release, void Function(double fraction) onProgress) async {
    if (!Platform.isAndroid) throw StateError('Android is required.');
    final cache = await getTemporaryDirectory();
    final file = File('${cache.path}/jm-broadband-${release.build}.apk');
    final client = http.Client();
    IOSink? sink;
    try {
      var url = release.download;
      http.StreamedResponse? response;
      for (var i = 0; i < 6; i++) {
        if (!trustedDownloadRedirect(url, release.download)) {
          throw const FormatException('Untrusted APK redirect.');
        }
        final req = http.Request('GET', url)..followRedirects = false;
        response = await client.send(req).timeout(const Duration(seconds: 30));
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final next = response.headers['location'];
          if (next == null) throw StateError('APK redirect missing URL.');
          url = url.resolve(next);
          continue;
        }
        break;
      }
      if (response == null ||
          response.statusCode != 200 ||
          !trustedDownloadRedirect(url, release.download)) {
        throw StateError('APK download failed.');
      }
      sink = file.openWrite();
      var received = 0;
      await for (final bytes
          in response.stream.timeout(const Duration(seconds: 40))) {
        sink.add(bytes);
        received += bytes.length;
        if (received > release.bytes) throw StateError('APK size mismatch.');
        onProgress(received / release.bytes);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (await file.length() != release.bytes) {
        throw StateError('APK download incomplete.');
      }
      final actual = (await sha256.bind(file.openRead()).first).toString();
      if (actual != release.sha256) throw StateError('APK SHA-256 mismatch.');
      return file;
    } catch (_) {
      if (sink != null) await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close();
    }
  }
}

class AppUpdatePage extends StatefulWidget {
  final AppRelease release;
  final VoidCallback? onLater;
  const AppUpdatePage({super.key, required this.release, this.onLater});
  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  bool busy = false;
  double progress = 0;
  String? error;
  Future<void> install() async {
    if (busy) return;
    setState(() {
      busy = true;
      progress = 0;
      error = null;
    });
    try {
      final apk = await AppUpdater.download(widget.release, (value) {
        if (mounted) setState(() => progress = value);
      });
      final result = await OpenFilex.open(apk.path,
          type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) throw StateError(result.message);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.release.required,
        child: Scaffold(
          appBar: AppBar(
              automaticallyImplyLeading: !widget.release.required,
              title: Text(
                  widget.release.required ? 'Update required' : 'App update')),
          body: Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.system_update_alt, size: 64),
                const SizedBox(height: 20),
                Text('Version ${widget.release.version}',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                Text(
                    widget.release.required
                        ? 'Install this update to continue using JM Broadband.'
                        : 'A newer version of JM Broadband is available.',
                    textAlign: TextAlign.center),
                if (widget.release.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(widget.release.notes, textAlign: TextAlign.center),
                ],
                if (busy) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  Text('${(progress * 100).round()}% downloaded'),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                    onPressed: busy ? null : install,
                    icon: const Icon(Icons.download),
                    label: Text(busy ? 'Downloading…' : 'Download & Install')),
                if (!widget.release.required)
                  TextButton(
                      onPressed:
                          widget.onLater ?? () => Navigator.maybePop(context),
                      child: const Text('Later')),
                const SizedBox(height: 14),
                const Text('Android will ask you to confirm installation.',
                    textAlign: TextAlign.center),
              ]),
            ),
          )),
        ),
      );
}
