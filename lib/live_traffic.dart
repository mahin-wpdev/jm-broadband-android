import 'dart:async';
import 'package:flutter/material.dart';

/// Polls a customer-owned live-traffic endpoint at most once/second in foreground.
/// Server may take longer; requests never overlap. No polling on other tabs.
class LiveTrafficPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() load;
  const LiveTrafficPage({super.key, required this.load});

  @override
  State<LiveTrafficPage> createState() => _LiveTrafficPageState();
}

class _LiveTrafficPageState extends State<LiveTrafficPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _requesting = false;
  bool _foreground = true;
  Map<String, dynamic>? _sample;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && mounted) {
      setState(() {
        _sample = null;
        _error = null;
      });
    } else if (_foreground) {
      _poll();
    }
  }

  Future<void> _poll() async {
    if (!mounted || !_foreground || _requesting) return;
    _requesting = true;
    try {
      final value = await widget.load();
      if (mounted && _foreground) {
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
        const SizedBox(height: 12),
        const Text('Usage totals, bills, package expiry and synced ONU optical '
            'readings are separate data sources and must not be treated as '
            'per-second readings.'),
      ],
    );
  }
}
