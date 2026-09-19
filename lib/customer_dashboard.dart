import 'package:flutter/material.dart';

/// Displays only data returned by the authenticated customer-dashboard API.
/// Unsupported live network metrics deliberately remain unavailable, not fabricated.
class CustomerDashboard extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() load;
  final Future<void> Function() onLogout;

  const CustomerDashboard({
    super.key,
    required this.load,
    required this.onLogout,
  });

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _refresh() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JM Broadband'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async => widget.onLogout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 42),
                    const SizedBox(height: 12),
                    const Text('Unable to load customer dashboard'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final customer = Map<String, dynamic>.from(data['customer'] as Map);
          final plan = Map<String, dynamic>.from(data['package'] as Map);
          final network = Map<String, dynamic>.from(data['network'] as Map);
          final state = plan['state']?.toString() ?? 'none';
          final price = plan['price_bdt'];
          final formattedPrice = price is num
              ? '৳${price.toStringAsFixed(0)} / plan'
              : 'Not available';
          final days = plan['days_remaining'];
          final daysText = state == 'none'
              ? 'No package yet'
              : state == 'expired'
                  ? 'Expired'
                  : '$days days remaining';
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Hello, ${customer['name'] ?? customer['username']}',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text('Account: ${customer['username']}',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                if (data['demo'] == true) ...[
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'DEMO DATA • Local test account. No live network or payment connection.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _InfoCard(
                  title: 'Active package',
                  icon: Icons.wifi,
                  rows: [
                    _InfoRow(
                        'Package', plan['name']?.toString() ?? 'No package'),
                    _InfoRow(
                        'Speed', plan['speed']?.toString() ?? 'Not available'),
                    _InfoRow('Price', formattedPrice),
                    _InfoRow('Status', state.toUpperCase()),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Expiry',
                  icon: Icons.calendar_month,
                  rows: [
                    _InfoRow(
                        'Expiry date', plan['expiration']?.toString() ?? '—'),
                    _InfoRow('Remaining', daysText),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Profile',
                  icon: Icons.person_outline,
                  rows: [
                    _InfoRow('Customer status',
                        customer['status']?.toString() ?? '—'),
                    _InfoRow('PPPoE username',
                        customer['pppoe_username']?.toString() ?? '—'),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Network (not connected yet)',
                  icon: Icons.router_outlined,
                  rows: [
                    _InfoRow(
                        'PPPoE online', _optional(network['pppoe_online'])),
                    _InfoRow('Download usage',
                        _optional(network['usage_download_bytes'])),
                    _InfoRow('Upload usage',
                        _optional(network['usage_upload_bytes'])),
                    _InfoRow('ONU RX', _optional(network['onu_rx_dbm'])),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _optional(Object? value) => value?.toString() ?? 'Not connected';
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoRow> rows;

  const _InfoCard(
      {required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 9),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(height: 24),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(row.label)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(row.value,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
