import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'traffic_chart.dart';
import 'traffic_history.dart';
import 'server_traffic_peak.dart';

/// Polls a customer-owned live-traffic endpoint at most once/second in foreground.
/// Server may take longer; requests never overlap. No polling on other tabs.
class LiveTrafficPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() load;
  final String historyKey;
  const LiveTrafficPage(
      {super.key, required this.load, required this.historyKey});

  @override
  State<LiveTrafficPage> createState() => _LiveTrafficPageState();
}

class _LiveTrafficPageState extends State<LiveTrafficPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _saveTimer;
  final _history = TrafficHistory();
  final _store = const FlutterSecureStorage();
  bool _historyLoaded = false;
  bool _dirty = false;
  bool _saving = false;
  bool _requesting = false;
  bool _foreground = true;
  Map<String, dynamic>? _sample;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) => _save());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && mounted) {
      _save();
      setState(() {
        _sample = null;
        _error = null;
      });
    } else if (_foreground) {
      _poll();
    }
  }

  Future<void> _restore() async {
    try {
      final value = await _store.read(key: widget.historyKey);
      if (value != null) _history.restore(value, DateTime.now());
    } catch (_) {
      // History storage is optional; live internet traffic must still load.
    } finally {
      _historyLoaded = true;
      if (mounted) {
        setState(() {});
        _poll();
      }
    }
  }

  Future<void> _save() async {
    if (!_historyLoaded || _saving || !_dirty) return;
    _saving = true;
    try {
      while (_dirty) {
        _dirty = false;
        await _store.write(key: widget.historyKey, value: _history.serialize());
      }
    } catch (_) {
      _dirty = true;
    } finally {
      _saving = false;
    }
  }

  Future<void> _poll() async {
    if (!mounted || !_foreground || _requesting || !_historyLoaded) return;
    _requesting = true;
    try {
      final value = await widget.load();
      if (mounted && _foreground) {
        final before = _history.count;
        _history.prune(DateTime.now());
        final added = _history.record(value, DateTime.now());
        if (added || before != _history.count) _dirty = true;
        setState(() {
          _sample = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && _foreground) {
        setState(() {
          _sample = null;
          _error =
              'Unable to update traffic. Check your connection or session.';
        });
      }
    } finally {
      _requesting = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveTimer?.cancel();
    _save();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _rate(Object? rate) {
    if (rate is! num) return 'Unavailable';
    if (rate < 1000) return '${rate.toStringAsFixed(0)} bps';
    if (rate < 1000000) return '${(rate / 1000).toStringAsFixed(1)} Kbps';
    return '${(rate / 1000000).toStringAsFixed(2)} Mbps';
  }

  @override
  Widget build(BuildContext context) {
    final s = _sample;
    final active = s?['available'] == true;
    final online = s?['online'] == true;
    final peak = ServerTrafficPeak.fromJson(s?['server_peak']);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Live internet traffic',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Refreshes up to once per second while this screen is open. '
            'Only the signed-in customer\'s PPPoE session is queried.'),
        const SizedBox(height: 14),
        if (s == null && _error == null) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (s != null) ...[
          Card(
              child: ListTile(
            leading: Icon(online ? Icons.wifi : Icons.wifi_off),
            title: Text(!active
                ? 'Not connected'
                : online
                    ? 'PPPoE online'
                    : 'PPPoE offline'),
            subtitle: Text('${s['message'] ?? s['observed_at'] ?? '—'}'),
          )),
          Card(
              child: ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download'),
            trailing: Text(_rate(s['download_bps'])),
          )),
          Card(
              child: ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Upload'),
            trailing: Text(_rate(s['upload_bps'])),
          )),
          const SizedBox(height: 8),
          Text('Observed: ${s['observed_at'] ?? '—'}'),
        ],
        const SizedBox(height: 18),
        Text('Traffic graph · last 60 seconds',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        TrafficChart(points: _history.lastMinutePoints(DateTime.now())),
        Text(
            '${_history.lastMinuteCount(DateTime.now())} live samples in the last 60 seconds.'),
        const SizedBox(height: 14),
        Text('Highest recorded RADIUS interval speed',
            style: Theme.of(context).textTheme.titleLarge),
        Card(
            child: Column(children: [
          ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Peak download'),
              subtitle: Text(peak.downloadAtMs == null
                  ? peak.message
                  : 'Recorded at ${TimeOfDay.fromDateTime(ServerTrafficPeak.observedLocal(peak.downloadAtMs)!).format(context)}'),
              trailing: Text(peak.downloadText)),
          ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Peak upload'),
              subtitle: Text(peak.uploadAtMs == null
                  ? peak.message
                  : 'Recorded at ${TimeOfDay.fromDateTime(ServerTrafficPeak.observedLocal(peak.uploadAtMs)!).format(context)}'),
              trailing: Text(peak.uploadText)),
        ])),
        const Text('When the server collector is enabled, recorded speed remains '
            'available while this phone is off. RADIUS accounting records '
            'interval-average rates, not one-second instantaneous peaks.'),
        const SizedBox(height: 12),
        const Text('Usage totals, bills, package expiry and synced ONU optical '
            'readings are separate data sources and must not be treated as '
            'per-second readings.'),
      ],
    );
  }
}
