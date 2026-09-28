import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/server_traffic_peak.dart';

void main() {
  test('server peak persists independently of phone history', () {
    final peak = ServerTrafficPeak.fromJson({
      'source': 'radius_accounting',
      'available': true, 'has_record': true,
      'download_bps': 50000000, 'upload_bps': 12000000,
      'download_at_ms': 1790000000000,
      'upload_at_ms': 1790000001000,
    });
    expect(peak.hasRecord, isTrue);
    expect(peak.downloadText, '50.00 Mbps');
    expect(peak.uploadText, '12.00 Mbps');
    expect(ServerTrafficPeak.observedLocal(peak.downloadAtMs), isNotNull);
  });
  test('legacy server never falls back to phone-derived peak', () {
    final peak = ServerTrafficPeak.fromJson(null);
    expect(peak.hasRecord, isFalse);
    expect(peak.downloadText, 'No record');
  });
  test('collector uninstalled keeps honest unavailable status', () {
    final peak = ServerTrafficPeak.fromJson({
      'source': 'radius_accounting', 'available': false,
      'message': 'Collector not installed',
    });
    expect(peak.hasRecord, isFalse);
    expect(peak.message, contains('Collector'));
  });
}
