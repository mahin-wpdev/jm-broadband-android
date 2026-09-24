import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/app_update.dart';

Map<String, dynamic> release({bool required = false}) => {
      'version': '1.0.8',
      'build_number': 9,
      'bytes': 51715568,
      'sha256': List.filled(64, 'a').join(),
      'required_update': required,
      'download_url': 'https://isp.example.com/panel/mobile-app-download.php',
      'notes': 'Fixed login',
    };

Map<String, dynamic> githubSnapshot() => {
      'tag_name': 'v1.0.10+11',
      'draft': false,
      'prerelease': false,
      'body': '<!-- jm-app-update:required=false -->\nOptional bug fix.',
      'assets': [
        {
          'name': 'jm-broadband.apk',
          'state': 'uploaded',
          'size': 52637783,
          'digest': 'sha256:${List.filled(64, 'a').join()}',
          'browser_download_url':
              'https://github.com/mahin-wpdev/jm-broadband-android/'
                  'releases/download/v1.0.10%2B11/jm-broadband.apk',
        },
      ],
    };

void main() {
  test('official GitHub fallback parses pinned APK, version and optional flag',
      () {
    final parsed = AppRelease.fromGithubSnapshot(githubSnapshot());
    expect(parsed.build, 11);
    expect(parsed.version, '1.0.10');
    expect(parsed.required, isFalse);
    expect(parsed.notes, 'Optional bug fix.');
    expect(parsed.download.host, 'github.com');
  });
  test('official GitHub fallback rejects wrong APK origin and checksum', () {
    final wrongHost = githubSnapshot();
    (wrongHost['assets'] as List).first['browser_download_url'] =
        'https://github.com.evil.example/mahin-wpdev/'
        'jm-broadband-android/releases/download/v1.0.10%2B11/jm-broadband.apk';
    expect(
        () => AppRelease.fromGithubSnapshot(wrongHost), throwsFormatException);
    final wrongChecksum = githubSnapshot();
    (wrongChecksum['assets'] as List).first['digest'] = 'sha256:bad';
    expect(() => AppRelease.fromGithubSnapshot(wrongChecksum),
        throwsFormatException);
  });
  test('update manifest path is beside panel API', () {
    expect(
        AppUpdater.manifest(
                Uri.parse('https://isp.example.com/panel/mobile-api.php'))
            .toString(),
        'https://isp.example.com/panel/mobile-app-version.php');
  });
  test('parses required update release', () {
    final parsed = AppRelease.fromJson(release(required: true));
    expect(parsed.build, 9);
    expect(parsed.required, isTrue);
    expect(parsed.download.host, 'isp.example.com');
  });
  test('rejects malformed hash and HTTP links', () {
    expect(
        () => AppRelease.fromJson({
              ...release(),
              'download_url': 'http://isp.example.com/update.apk',
            }),
        throwsFormatException);
    expect(
        () => AppRelease.fromJson({
              ...release(),
              'sha256': 'invalid',
            }),
        throwsFormatException);
  });
  test('only trusted GitHub release redirects are allowed', () {
    final panel =
        Uri.parse('https://isp.example.com/panel/mobile-app-download.php');
    for (final url in [
      'https://isp.example.com/panel/mobile-app-download.php',
      'https://github.com/mahin-wpdev/jm-broadband-android/releases/download/v1.0.8%2B9/jm-broadband.apk',
      'https://release-assets.githubusercontent.com/file',
    ]) {
      expect(AppUpdater.trustedDownloadRedirect(Uri.parse(url), panel), isTrue);
    }
    for (final url in [
      'http://github.com/mahin-wpdev/jm-broadband-android/releases/download/a.apk',
      'https://github.com/other-owner/other-repo/releases/download/a.apk',
      'https://github.com.evil.example/releases/download/a.apk',
      'https://evil.example/file.apk',
    ]) {
      expect(
          AppUpdater.trustedDownloadRedirect(Uri.parse(url), panel), isFalse);
    }
  });
  testWidgets('required update cannot be postponed', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AppUpdatePage(
      release: AppRelease.fromJson(release(required: true)),
    )));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Download & Install'), findsOneWidget);
  });
  testWidgets('optional update has Later button', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AppUpdatePage(
      release: AppRelease.fromJson(release()),
    )));
    expect(find.text('Later'), findsOneWidget);
  });
}
