/// Highest speeds must come from server-side RADIUS accounting.
class ServerTrafficPeak {
  final bool available;
  final bool hasRecord;
  final num? downloadBps;
  final num? uploadBps;
  final int? downloadAtMs;
  final int? uploadAtMs;
  final String message;
  const ServerTrafficPeak({required this.available, required this.hasRecord,
    this.downloadBps, this.uploadBps, this.downloadAtMs, this.uploadAtMs,
    required this.message});
  static num? _rate(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value : null;
  static int? _stamp(Object? value) =>
      value is int && value > 0 ? value : null;
  factory ServerTrafficPeak.fromJson(Object? json) {
    if (json is! Map || json['source'] != 'radius_accounting') {
      return const ServerTrafficPeak(
        available: false, hasRecord: false,
        message: 'Server peak history is not supported by this Panel.');
    }
    final available = json['available'] == true;
    final record = available && json['has_record'] == true;
    return ServerTrafficPeak(
      available: available, hasRecord: record,
      downloadBps: record ? _rate(json['download_bps']) : null,
      uploadBps: record ? _rate(json['upload_bps']) : null,
      downloadAtMs: record ? _stamp(json['download_at_ms']) : null,
      uploadAtMs: record ? _stamp(json['upload_at_ms']) : null,
      message: (json['message'] ?? 'No server-recorded peak is available.')
          .toString(),
    );
  }
  String get downloadText => _format(downloadBps);
  String get uploadText => _format(uploadBps);
  static String _format(num? bps) => bps == null
      ? 'No record' : '${(bps / 1000000).toStringAsFixed(2)} Mbps';
  static DateTime? observedLocal(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
          .toLocal();
}
