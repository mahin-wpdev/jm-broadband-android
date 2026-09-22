import 'package:flutter/material.dart';
import 'live_traffic.dart';
import 'server_traffic_peak.dart';

/// Actual read-only Panel data. The client never supplies an actor/customer ID.
class PanelWorkspace extends StatefulWidget {
  final String role;
  final String name;
  final Future<Map<String, dynamic>> Function(String section) load;
  final Future<Map<String, dynamic>> Function() loadTraffic;
  final String trafficHistoryKey;
  final Future<void> Function() onLogout;

  const PanelWorkspace({
    super.key,
    required this.role,
    required this.name,
    required this.load,
    required this.loadTraffic,
    required this.trafficHistoryKey,
    required this.onLogout,
  });

  @override
  State<PanelWorkspace> createState() => _PanelWorkspaceState();
}

class _PanelWorkspaceState extends State<PanelWorkspace> {
  int selected = 0;
  late Future<Map<String, dynamic>> pending;

  List<_Page> get pages => switch (widget.role) {
        'customer' => const [
            _Page('Home', 'home', Icons.home_outlined),
            _Page('Live', 'traffic', Icons.speed_outlined),
            _Page('Bills', 'sales', Icons.receipt_long_outlined),
            _Page('ONU', 'onus', Icons.router_outlined),
            _Page('Inbox', 'inbox', Icons.inbox_outlined),
            _Page('Account', 'account', Icons.person_outline),
          ],
        'reseller' => const [
            _Page('Overview', 'home', Icons.dashboard_outlined),
            _Page('Customers', 'customers', Icons.group_outlined),
            _Page('Sales', 'sales', Icons.receipt_long_outlined),
            _Page('ONU', 'onus', Icons.router_outlined),
            _Page('Account', 'account', Icons.person_outline),
          ],
        _ => const [
            _Page('Overview', 'home', Icons.dashboard_outlined),
            _Page('Customers', 'customers', Icons.group_outlined),
            _Page('Resellers', 'resellers', Icons.groups_outlined),
            _Page('Sales', 'sales', Icons.receipt_long_outlined),
            _Page('More', 'more', Icons.apps_outlined),
          ],
      };

  @override
  void initState() {
    super.initState();
    pending = widget.load('home');
  }

  void change(int index) {
    setState(() {
      selected = index;
      final section = pages[index].section;
      pending =
          (section == 'account' || section == 'more' || section == 'traffic')
              ? Future.value(<String, dynamic>{'available': true})
              : widget.load(section);
    });
  }

  Future<void> refresh() async {
    final section = pages[selected].section;
    final next = widget.load(section);
    setState(() => pending = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder renders the exact API error and exposes Retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = pages[selected];
    return Scaffold(
      appBar: AppBar(
        title: Text('Arivo · ${page.title}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: (page.section == 'account' ||
                    page.section == 'more' ||
                    page.section == 'traffic')
                ? null
                : refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: switch (page.section) {
        'account' => _AccountPage(name: widget.name, role: widget.role),
        'traffic' => LiveTrafficPage(
            load: widget.loadTraffic, historyKey: widget.trafficHistoryKey),
        'more' => _MorePage(load: widget.load),
        _ => FutureBuilder<Map<String, dynamic>>(
            future: pending,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Message(
                  title: 'Unable to load ${page.title}',
                  details: '${snapshot.error}',
                  retry: refresh,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              if (data['available'] == false) {
                return _Message(
                  title: '${page.title} unavailable',
                  details:
                      '${data['message'] ?? 'This server does not support this feature.'}',
                  retry: refresh,
                );
              }
              return RefreshIndicator(
                onRefresh: refresh,
                child: _SectionView(section: page.section, data: data),
              );
            },
          ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: change,
        destinations: [
          for (final p in pages)
            NavigationDestination(icon: Icon(p.icon), label: p.title),
        ],
      ),
    );
  }
}

class _Page {
  final String title;
  final String section;
  final IconData icon;
  const _Page(this.title, this.section, this.icon);
}

class _SectionView extends StatelessWidget {
  final String section;
  final Map<String, dynamic> data;
  const _SectionView({required this.section, required this.data});

  @override
  Widget build(BuildContext context) {
    final elements = <Widget>[];
    if (data['demo'] == true) {
      elements.add(const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child:
              Text('LOCAL DEMO ACCOUNT · Not live internet or payment data.'),
        ),
      ));
    }
    if (section == 'home') {
      elements.addAll(_homeCards(context, data));
    } else {
      final raw = data['items'];
      final rows = raw is List ? raw : const [];
      if (rows.isEmpty) {
        elements.add(const _InfoCard(
          title: 'No records',
          values: {'Result': 'No matching records on this Panel.'},
        ));
      } else {
        for (final row in rows) {
          if (row is Map) {
            final map = Map<String, dynamic>.from(row);
            // The backend exposes an explicit, limited field set per role.
            elements.add(_InfoCard(
              title: _rowTitle(map, section),
              values: map,
            ));
          }
        }
      }
    }
    if (data['note'] is String) {
      elements.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(data['note'] as String,
            style: Theme.of(context).textTheme.bodySmall),
      ));
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: elements,
    );
  }

  String _rowTitle(Map<String, dynamic> row, String section) {
    switch (section) {
      case 'sales':
        return 'Invoice ${row['invoice'] ?? row['id'] ?? '—'}';
      case 'customers':
        return '${row['fullname'] ?? row['username'] ?? 'Customer'}';
      case 'resellers':
        return '${row['name'] ?? 'Reseller'}';
      case 'onus':
        return 'ONU ${row['username'] ?? row['id'] ?? '—'}';
      case 'inbox':
        return '${row['subject'] ?? 'Message'}';
      default:
        return '${row['name_plan'] ?? row['name'] ?? row['id'] ?? 'Record'}';
    }
  }

  List<Widget> _homeCards(BuildContext context, Map<String, dynamic> data) {
    if (data['role'] == 'customer') {
      final profile = _asMap(data['profile']);
      final package = _asMap(data['package']);
      final network = _asMap(data['network']);
      network.remove('usage_download_bytes');
      network.remove('usage_upload_bytes');
      final monthly = _asMap(data['monthly_usage']);
      return [
        Text('Hello, ${profile['name'] ?? profile['username'] ?? ''}',
            style: Theme.of(context).textTheme.headlineSmall),
        _InfoCard(title: 'Your profile', values: profile),
        _InfoCard(title: 'Your internet package', values: package),
        _monthlyCard(monthly),
        _serverPeakCard(ServerTrafficPeak.fromJson(data['traffic_peak'])),
        if (network.values.any((value) => value != null))
          _InfoCard(title: 'Network summary', values: network),
        const Text(
            'See the Live tab for current PPPoE speed and online status.'),
      ];
    }
    return [
      Text(data['role'] == 'reseller' ? 'Reseller overview' : 'Admin overview',
          style: Theme.of(context).textTheme.headlineSmall),
      _InfoCard(title: 'Panel records', values: _asMap(data['summary'])),
    ];
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

String _usageGb(Object? value) {
  final bytes = value is num ? value : num.tryParse('${value ?? ''}');
  if (bytes == null || !bytes.isFinite || bytes < 0) return 'Unavailable';
  return '${(bytes / 1000000000).toStringAsFixed(2)} GB';
}

Widget _monthlyCard(Map<String, dynamic> usage) {
  final available = usage['available'] == true &&
      _usageGb(usage['download_bytes']) != 'Unavailable' &&
      _usageGb(usage['upload_bytes']) != 'Unavailable' &&
      _usageGb(usage['total_bytes']) != 'Unavailable';
  if (!available) {
    return _InfoCard(title: 'Monthly bandwidth usage', values: {
      'Status': 'Unavailable',
      'Reason': usage['note'] ??
          'This Panel has no verified monthly accounting data.',
    });
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _InfoCard(title: 'Monthly bandwidth usage (${usage['month']})', values: {
      'Download': _usageGb(usage['download_bytes']),
      'Upload': _usageGb(usage['upload_bytes']),
      'Total': _usageGb(usage['total_bytes']),
    }),
    if (usage['note'] is String)
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(usage['note'] as String)),
  ]);
}

Widget _serverPeakCard(ServerTrafficPeak peak) {
  if (!peak.hasRecord) {
    return _InfoCard(title: 'Server-recorded highest speed', values: {
      'Status': peak.message,
    });
  }
  return _InfoCard(title: 'Server-recorded highest speed', values: {
    'Download': peak.downloadText,
    'Upload': peak.uploadText,
    'Measurement': 'RADIUS accounting interval average',
    'History': 'Persisted independently of this phone',
  });
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> values;
  const _InfoCard({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 22),
            for (final entry in values.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(_title(entry.key))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value == null || entry.value == ''
                            ? 'Unavailable'
                            : '${entry.value}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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

String _title(String name) => name
    .replaceAll('_', ' ')
    .split(' ')
    .map((word) =>
        word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

class _Message extends StatelessWidget {
  final String title;
  final String details;
  final Future<void> Function() retry;
  const _Message({
    required this.title,
    required this.details,
    required this.retry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 40),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(details, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  final String name;
  final String role;
  const _AccountPage({required this.name, required this.role});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(title: 'Signed-in account', values: {
            'Name': name,
            'Role': role,
            'Access': 'Read-only Panel data',
          }),
          const _InfoCard(
            title: 'Support',
            values: {
              'Status': 'Use the support contact provided by your ISP.',
              'Tickets': 'Not configured for this Panel API.',
            },
          ),
        ],
      );
}

class _MorePage extends StatelessWidget {
  final Future<Map<String, dynamic>> Function(String section) load;
  const _MorePage({required this.load});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Administrator · Additional Panel records'),
          for (final entry in const [
            _Page('Plans', 'plans', Icons.wifi_outlined),
            _Page('Routers', 'routers', Icons.router_outlined),
            _Page('ONU inventory', 'onus', Icons.cable_outlined),
          ])
            Card(
              child: ListTile(
                leading: Icon(entry.icon),
                title: Text(entry.title),
                subtitle: const Text('Read-only'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (context) =>
                      _StandaloneSection(page: entry, load: load),
                )),
              ),
            ),
        ],
      );
}

class _StandaloneSection extends StatefulWidget {
  final _Page page;
  final Future<Map<String, dynamic>> Function(String section) load;
  const _StandaloneSection({required this.page, required this.load});
  @override
  State<_StandaloneSection> createState() => _StandaloneSectionState();
}

class _StandaloneSectionState extends State<_StandaloneSection> {
  late Future<Map<String, dynamic>> pending;
  @override
  void initState() {
    super.initState();
    pending = widget.load(widget.page.section);
  }

  Future<void> refresh() async {
    final next = widget.load(widget.page.section);
    setState(() => pending = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.page.title)),
        body: FutureBuilder<Map<String, dynamic>>(
          future: pending,
          builder: (context, result) {
            if (result.hasError) {
              return _Message(
                title: 'Could not load ${widget.page.title}',
                details: '${result.error}',
                retry: refresh,
              );
            }
            if (!result.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = result.data!;
            if (data['available'] == false) {
              return _Message(
                title: 'Not available',
                details: '${data['message']}',
                retry: refresh,
              );
            }
            return RefreshIndicator(
              onRefresh: refresh,
              child: _SectionView(section: widget.page.section, data: data),
            );
          },
        ),
      );
}
