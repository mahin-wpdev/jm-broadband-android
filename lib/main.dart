import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_update.dart';
import 'panel_workspace.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JmApp());
}

// Android may restore encrypted preferences without their device-bound Keystore key.
// Treat that old local session as invalid rather than trapping the app on splash.
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
);

/// Keeps the path to the existing panel; does not guess arbitrary server paths.
/// API file is installed beside panel/init.php.
Uri normalizeServer(String input) {
  var value = input.trim();
  if (value.isEmpty) throw const FormatException('Enter a server address');
  if (!value.contains('://')) value = 'https://$value';
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException(
        'Use a valid HTTPS domain or IP and optional /panel path');
  }
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (path.endsWith('/mobile-api.php')) return uri.replace(path: path);
  return uri.replace(path: '$path/mobile-api.php');
}

// An Android key-reset result is not a saved server address.
Uri? restoredServerUri(String? value) {
  if (value == null || value == 'Data has been reset') return null;
  return normalizeServer(value);
}

const _localCertBase64 = String.fromEnvironment('JM_LOCAL_CERT_B64');

http.Client createApiClient(Uri url) {
  final isLocalDebugServer = kDebugMode &&
      url.scheme == 'https' &&
      url.host == 'localhost' &&
      url.port == 8443 &&
      _localCertBase64.isNotEmpty;

  if (!isLocalDebugServer) {
    return http.Client();
  }

  final context = SecurityContext(withTrustedRoots: true);

  context.setTrustedCertificatesBytes(
    base64Decode(_localCertBase64),
  );

  return IOClient(HttpClient(context: context));
}

class MobileApi {
  Uri? endpoint;
  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? user;

  Future<void> restore() async {
    try {
      // Include the first read in the recovery boundary: Android backups can
      // restore ciphertext after the encryption key was destroyed on uninstall.
      final server = await _storage.read(key: 'server');
      // Do not mistake the plugin's recovery marker for the server URL.
      final restoredEndpoint = restoredServerUri(server);
      if (restoredEndpoint == null) return;
      endpoint = restoredEndpoint;
      refreshToken = await _storage.read(key: 'refresh:${endpoint.toString()}');
      if (refreshToken != null) await refresh();
      if (accessToken != null) await me();
    } catch (_) {
      // A stale or undecryptable local login must never block first-run UI.
      accessToken = null;
      refreshToken = null;
      user = null;
      endpoint = null;
    }
  }

  Future<Map<String, dynamic>> request(String action,
      {Map<String, dynamic>? body,
      bool authorized = true,
      Map<String, String>? query,
      bool retry = true}) async {
    if (endpoint == null) throw StateError('Server is not configured');
    final url =
        endpoint!.replace(queryParameters: {'action': action, ...?query});
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authorized && accessToken != null)
        'Authorization': 'Bearer $accessToken',
    };
    // Never follow redirects: credentials must not cross server origins.
    final client = createApiClient(url);
    late final http.Response result;
    try {
      final req = http.Request(body == null ? 'GET' : 'POST', url);
      req.followRedirects = false;
      req.headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed =
          await client.send(req).timeout(const Duration(seconds: 15));
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        throw StateError(
            'Server redirected the API request; verify its HTTPS panel URL');
      }
      result = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw StateError(
          'Server connection timed out. Check the HTTPS server connection.');
    } on SocketException {
      throw StateError(
          'Cannot reach the Mobile API over HTTPS. Check your network or VPN and the server URL.');
    } on HandshakeException {
      throw StateError(
          'HTTPS certificate verification failed. Check the server certificate.');
    } finally {
      client.close();
    }
    Map<String, dynamic> response;
    try {
      response = Map<String, dynamic>.from(jsonDecode(result.body) as Map);
    } catch (_) {
      throw StateError('Server did not return Mobile API JSON');
    }
    if (result.statusCode == 401 &&
        authorized &&
        retry &&
        refreshToken != null) {
      await refresh();
      return request(action,
          body: body, authorized: authorized, query: query, retry: false);
    }
    if (result.statusCode >= 400) {
      throw StateError(response['error']?.toString() ?? 'Server error');
    }
    return response;
  }

  Future<String> discover(String server) async {
    endpoint = normalizeServer(server);
    final data = await request('server-info', authorized: false);
    final info = Map<String, dynamic>.from(data['data'] as Map);
    if (info['api_version'] != '1.0' || info['authentication'] != 'unified') {
      throw StateError('Incompatible server API');
    }
    return info['company_name']?.toString() ?? endpoint!.host;
  }

  Future<void> login(String server, String username, String password) async {
    // A previous server's token must never be used after changing server URL.
    accessToken = null;
    refreshToken = null;
    user = null;
    await discover(server);
    final data = await request('login',
        authorized: false, body: {'username': username, 'password': password});
    final payload = Map<String, dynamic>.from(data['data'] as Map);
    accessToken = payload['access_token'] as String;
    refreshToken = payload['refresh_token'] as String;
    user = Map<String, dynamic>.from(payload['user'] as Map);
    await _storage.write(key: 'server', value: endpoint.toString());
    await _storage.write(
        key: 'refresh:${endpoint.toString()}', value: refreshToken);
  }

  Future<void> refresh() async {
    if (refreshToken == null) throw StateError('Please log in');
    final data = await request('refresh',
        authorized: false, body: {'refresh_token': refreshToken});
    final payload = Map<String, dynamic>.from(data['data'] as Map);
    accessToken = payload['access_token'] as String;
    refreshToken = payload['refresh_token'] as String;
    await _storage.write(
        key: 'refresh:${endpoint.toString()}', value: refreshToken);
  }

  Future<void> me() async {
    final data = await request('me');
    user = Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<void> logout() async {
    try {
      if (accessToken != null) await request('logout', body: {});
    } catch (_) {
      // Remove the local session even when server is unreachable.
    } finally {
      if (endpoint != null) {
        await _storage.delete(key: 'refresh:${endpoint.toString()}');
      }
      accessToken = null;
      refreshToken = null;
      user = null;
    }
  }
}

class JmApp extends StatefulWidget {
  final MobileApi? initialApi;
  const JmApp({super.key, this.initialApi});
  @override
  State<JmApp> createState() => _JmAppState();
}

class _JmAppState extends State<JmApp> with WidgetsBindingObserver {
  late final MobileApi api = widget.initialApi ?? MobileApi();
  bool loading = true;
  bool checkingUpdate = false;
  AppRelease? updateRelease;
  static final Uri _defaultUpdateEndpoint =
      normalizeServer('https://27.147.201.165/panel');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading && updateRelease == null) {
      _checkForUpdate();
    }
  }
  Future<bool> _checkForUpdate({Uri? endpoint, bool manual = false}) async {
    if (checkingUpdate) return updateRelease != null;
    checkingUpdate = true;
    try {
      final release = await AppUpdater.check(
          endpoint ?? api.endpoint ?? _defaultUpdateEndpoint);
      if (mounted) setState(() => updateRelease = release);
      return release != null;
    } catch (_) {
      if (manual) rethrow;
      return false;
    } finally {
      checkingUpdate = false;
    }
  }

  Future<void> _boot() async {
    try {
      await api.restore().timeout(const Duration(seconds: 25));
    } catch (_) {
      // Storage/plugin errors or hung restoration must show the Login screen.
      api.accessToken = null;
      api.refreshToken = null;
      api.user = null;
      api.endpoint = null;
    }
    await _checkForUpdate(endpoint: api.endpoint ?? _defaultUpdateEndpoint);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Arivo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF10A88B))),
        home: loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : updateRelease != null
                ? AppUpdatePage(release: updateRelease!,
                    onLater: updateRelease!.required
                        ? null
                        : () => setState(() => updateRelease = null))
                : api.user == null
                    ? LoginScreen(api: api, onLogin: () async {
                        await _checkForUpdate(endpoint: api.endpoint);
                        if (mounted) setState(() {});
                      })
                    : RoleDashboard(api: api,
                        onLogout: () => setState(() {}),
                        onCheckForUpdates: () => _checkForUpdate(
                            endpoint: api.endpoint, manual: true)),
      );
}

class LoginScreen extends StatefulWidget {
  final MobileApi api;
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.api, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final server = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    server.text =
        widget.api.endpoint?.toString().replaceAll('/mobile-api.php', '') ??
            'https://27.147.201.165/panel';
  }

  @override
  void dispose() {
    server.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.login(server.text, username.text.trim(), password.text);
      if (mounted) widget.onLogin();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset('assets/branding/logo.png',
                              height: 100, fit: BoxFit.contain),
                          const SizedBox(height: 15),
                          const Text('Arivo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.bold)),
                          const Text('Customer • Reseller • Admin',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 35),
                          TextField(
                              controller: server,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                  labelText: 'Server IP / Domain',
                                  hintText: 'https://isp.example.com/panel',
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 15),
                          TextField(
                              controller: username,
                              decoration: const InputDecoration(
                                  labelText: 'Username',
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 15),
                          TextField(
                              controller: password,
                              obscureText: true,
                              onSubmitted: (_) => submit(),
                              decoration: const InputDecoration(
                                  labelText: 'Password',
                                  border: OutlineInputBorder())),
                          if (error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Text(error!,
                                    style: const TextStyle(color: Colors.red))),
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: busy ? null : submit,
                              child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child:
                                      Text(busy ? 'Connecting…' : 'Sign In'))),
                          const SizedBox(height: 16),
                          const Text(
                              'HTTPS required. Your username and password are sent only to the selected server.',
                              textAlign: TextAlign.center),
                        ])))),
      );
}

class RoleDashboard extends StatelessWidget {
  final MobileApi api;
  final VoidCallback onLogout;
  final Future<bool> Function() onCheckForUpdates;
  const RoleDashboard({super.key, required this.api,
      required this.onLogout, required this.onCheckForUpdates});
  @override
  Widget build(BuildContext context) {
    final user = api.user ?? {};
    final role = user['role']?.toString() ?? 'unknown';
    return PanelWorkspace(
      role: role,
      name: (user['name'] ?? user['username'] ?? '').toString(),
      load: (section) async {
        final response =
            await api.request('mobile-data', query: {'section': section});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      loadTraffic: () async {
        final response = await api.request('live-traffic');
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      trafficHistoryKey: 'arivo:traffic:${api.endpoint}:${user['role']}:'
          '${user['id'] ?? user['username']}',
      onCheckForUpdates: onCheckForUpdates,
      onLogout: () async {
        await api.logout();
        onLogout();
      },
    );
  }
}
