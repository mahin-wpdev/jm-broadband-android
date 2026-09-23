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

void main() {
  test('update manifest path is beside panel API', () {
    expect(AppUpdater.manifest(Uri.parse(
      'https://isp.example.com/panel/mobile-api.php')).toString(),
      'https://isp.example.com/panel/mobile-app-version.php');
  });
  test('parses required update release', () {
    final parsed = AppRelease.fromJson(release(required: true));
    expect(parsed.build, 9);
    expect(parsed.required, isTrue);
    expect(parsed.download.host, 'isp.example.com');
  });
  test('rejects malformed hash and HTTP links', () {
    expect(() => AppRelease.fromJson({
      ...release(), 'download_url': 'http://isp.example.com/update.apk',
    }), throwsFormatException);
    expect(() => AppRelease.fromJson({
      ...release(), 'sha256': 'invalid',
    }), throwsFormatException);
  });
  testWidgets('required update cannot be postponed', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AppUpdatePage(
      release: AppRelease.fromJson(release(required: true)),
    )));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Download & Install'), findsOneWidget);
  });
  testWidgets('optional update has Later button', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AppUpdatePage(
      release: AppRelease.fromJson(release()),
    )));
    expect(find.text('Later'), findsOneWidget);
  });
}