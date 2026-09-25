import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/main.dart';

void main() {
  test('JM public IP defaults to standard HTTPS 443 on every network', () {
    expect(normalizeServer('https://27.147.201.165/panel').toString(),
        'https://27.147.201.165/panel/mobile-api.php');
    expect(normalizeServer('27.147.201.165').toString(),
        'https://27.147.201.165/panel/mobile-api.php');
    expect(
        restoredServerUri('https://27.147.201.165/panel/mobile-api.php')!.port,
        443);
  });
  test('explicit 443, explicit 8443, and unrelated servers are respected', () {
    expect(normalizeServer('https://27.147.201.165:443/panel').port, 443);
    expect(normalizeServer('https://27.147.201.165:8443/panel').port, 8443);
    expect(normalizeServer('https://isp.example.com/panel').port, 443);
  });
  test('JM endpoint can fail over between public 8443 and LAN-friendly 443',
      () {
    final mobile =
        Uri.parse('https://27.147.201.165:8443/panel/mobile-api.php');
    final lan = jmAlternateEndpoint(mobile);
    expect(lan, isNotNull);
    expect(lan!.port, 443);
    expect(lan.path, '/panel/mobile-api.php');
    expect(jmAlternateEndpoint(lan)!.port, 8443);
    expect(
        jmAlternateEndpoint(
            Uri.parse('https://isp.example.com/panel/mobile-api.php')),
        isNull);
  });

  test('adds HTTPS and API path', () {
    expect(normalizeServer('isp.example.com/panel').toString(),
        'https://isp.example.com/panel/mobile-api.php');
  });
  test('does not duplicate API filename', () {
    expect(normalizeServer('https://isp.example.com/panel/mobile-api.php').path,
        '/panel/mobile-api.php');
  });
  test('refuses insecure HTTP', () {
    expect(
        () => normalizeServer('http://isp.example.com'), throwsFormatException);
  });
  test('Android decryption-reset marker is not a restored server URL', () {
    expect(restoredServerUri('Data has been reset'), isNull);
    expect(restoredServerUri(null), isNull);
    expect(restoredServerUri('https://isp.example.com/panel')!.host,
        'isp.example.com');
  });
}
