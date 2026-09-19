import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/main.dart';

void main() {
  test('adds HTTPS and API path', () {
    expect(normalizeServer('isp.example.com/panel').toString(),
        'https://isp.example.com/panel/mobile-api.php');
  });
  test('does not duplicate API filename', () {
    expect(normalizeServer('https://isp.example.com/panel/mobile-api.php').path,
        '/panel/mobile-api.php');
  });
  test('refuses insecure HTTP', () {
    expect(() => normalizeServer('http://isp.example.com'), throwsFormatException);
  });
}
