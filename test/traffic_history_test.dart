import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/traffic_history.dart';

Map<String, dynamic> sample(num down, num up) => {
      'available': true,
      'online': true,
      'download_bps': down,
      'upload_bps': up,
    };

void main() {
  test('retains last-hour peaks for each direction independently', () {
    final history = TrafficHistory();
    final now = DateTime(2026, 9, 21, 17);
    expect(
        history.record(sample(50000000, 2000000),
            now.subtract(const Duration(minutes: 45))),
        isTrue);
    expect(
        history.record(sample(25000000, 9000000),
            now.subtract(const Duration(minutes: 30))),
        isTrue);
    expect(history.record(sample(35000000, 4000000), now), isTrue);
    expect(history.downloadPeak?.downloadBps, 50000000);
    expect(history.uploadPeak?.uploadBps, 9000000);
    history.prune(now.add(const Duration(minutes: 16)));
    expect(history.downloadPeak?.downloadBps, 35000000);
    expect(history.uploadPeak?.uploadBps, 9000000);
  });
  test('survives serialization and does not invent offline samples', () {
    final history = TrafficHistory();
    final now = DateTime(2026, 9, 21, 17);
    expect(history.record(sample(12000000, 500000), now), isTrue);
    expect(
        history.record({
          'available': true,
          'online': false,
          'download_bps': 0,
          'upload_bps': 0,
        }, now.add(const Duration(seconds: 1))),
        isFalse);
    final restored = TrafficHistory();
    restored.restore(history.serialize(), now.add(const Duration(seconds: 2)));
    expect(restored.count, 1);
    expect(restored.downloadPeak?.downloadBps, 12000000);
    restored.restore('corrupted data', now);
    expect(restored.count, 1);
    restored.prune(now.add(const Duration(hours: 2)));
    expect(restored.count, 0);
    expect(restored.downloadPeak, isNull);
  });

  test('graph shows only the latest minute while hour peak remains', () {
    final history = TrafficHistory();
    final now = DateTime(2026, 9, 21, 18);
    history.record(
        sample(90000000, 1000000), now.subtract(const Duration(minutes: 25)));
    history.record(
        sample(15000000, 3000000), now.subtract(const Duration(seconds: 59)));
    history.record(sample(25000000, 5000000), now);
    expect(history.lastMinuteCount(now), 2);
    expect(history.downloadPeak?.downloadBps, 90000000);
    expect(history.uploadPeak?.uploadBps, 5000000);
    expect(history.lastMinuteCount(now.add(const Duration(seconds: 2))), 1);
  });
}
