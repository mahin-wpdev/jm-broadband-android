import 'dart:convert';

/// A sample received while the signed-in customer's Live page is foreground.
class TrafficPoint {
  final int atMs;
  final double downloadBps;
  final double uploadBps;

  const TrafficPoint(this.atMs, this.downloadBps, this.uploadBps);

  List<num> toJson() => [atMs, downloadBps.round(), uploadBps.round()];

  static TrafficPoint? fromJson(Object? raw) {
    if (raw is! List || raw.length != 3) return null;
    final at = raw[0], down = raw[1], up = raw[2];
    if (at is! num ||
        down is! num ||
        up is! num ||
        !at.isFinite ||
        !down.isFinite ||
        !up.isFinite ||
        at < 0 ||
        down < 0 ||
        up < 0) {
      return null;
    }
    return TrafficPoint(at.toInt(), down.toDouble(), up.toDouble());
  }
}

class TrafficHistory {
  static const window = Duration(hours: 1);
  final List<TrafficPoint> _points = [];
  List<TrafficPoint> get points => List.unmodifiable(_points);
  int get count => _points.length;
  List<TrafficPoint> lastMinutePoints(DateTime now) {
    final cutoff =
        now.millisecondsSinceEpoch - const Duration(seconds: 60).inMilliseconds;
    return List.unmodifiable(_points.where((p) =>
        p.atMs >= cutoff && p.atMs <= now.millisecondsSinceEpoch + 5000));
  }

  int lastMinuteCount(DateTime now) {
    final cutoff =
        now.millisecondsSinceEpoch - const Duration(seconds: 60).inMilliseconds;
    return _points
        .where((p) =>
            p.atMs >= cutoff && p.atMs <= now.millisecondsSinceEpoch + 5000)
        .length;
  }

  void prune(DateTime now) {
    final cutoff = now.millisecondsSinceEpoch - window.inMilliseconds;
    _points.removeWhere(
        (p) => p.atMs < cutoff || p.atMs > now.millisecondsSinceEpoch + 5000);
  }

  void restore(String value, DateTime now) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is! List) return;
      final recovered = parsed
          .map(TrafficPoint.fromJson)
          .whereType<TrafficPoint>()
          .toList()
        ..sort((a, b) => a.atMs.compareTo(b.atMs));
      _points.addAll(recovered);
      _points.sort((a, b) => a.atMs.compareTo(b.atMs));
      _points.removeWhere((p) => p.atMs < 0);
      prune(now);
    } catch (_) {
      // Corrupted local samples must not interrupt the live API.
    }
  }

  bool record(Map<String, dynamic> sample, DateTime now) {
    prune(now);
    if (sample['available'] != true || sample['online'] != true) return false;
    final down = sample['download_bps'];
    final up = sample['upload_bps'];
    if (down is! num ||
        up is! num ||
        !down.isFinite ||
        !up.isFinite ||
        down < 0 ||
        up < 0) {
      return false;
    }
    final at = now.millisecondsSinceEpoch;
    if (_points.isNotEmpty && at <= _points.last.atMs) return false;
    _points.add(TrafficPoint(at, down.toDouble(), up.toDouble()));
    return true;
  }

  TrafficPoint? get downloadPeak {
    if (_points.isEmpty) return null;
    return _points.reduce((a, b) => a.downloadBps >= b.downloadBps ? a : b);
  }

  TrafficPoint? get uploadPeak {
    if (_points.isEmpty) return null;
    return _points.reduce((a, b) => a.uploadBps >= b.uploadBps ? a : b);
  }

  String serialize() => jsonEncode(_points.map((p) => p.toJson()).toList());
}
