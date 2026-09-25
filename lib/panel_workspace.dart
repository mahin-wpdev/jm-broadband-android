import 'dart:async';
import 'package:flutter/material.dart';
import 'live_traffic.dart';
import 'admin_recharge_page.dart';
import 'admin_customer_pages.dart';
import 'admin_onu_page.dart';
import 'support_tickets_page.dart';

/// Actual read-only Panel data. The client never supplies an actor/customer ID.
class PanelWorkspace extends StatefulWidget {
  final String role;
  final String name;
  final Future<Map<String, dynamic>> Function(String section) load;
  final Future<Map<String, dynamic>> Function() loadTraffic;
  final String trafficHistoryKey;
  final Future<Map<String, dynamic>> Function(String query) searchRecharge;
  final Future<Map<String, dynamic>> Function(String query) searchCustomers;
  final Future<Map<String, dynamic>> Function(String query, String filter)
      loadAdminOnus;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> input)
      assignOnu;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> input)
      unassignOnu;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> input)
      removeOnu;
  final Future<Map<String, dynamic>> Function() loadTickets;
  final Future<Map<String, dynamic>> Function(int ticketId) ticketDetail;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)
      createTicket;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)
      updateTicket;
  final Future<Map<String, dynamic>> Function() ticketNotifications;
  final Future<Map<String, dynamic>> Function(
      int notificationId, String notificationType) readTicketNotification;
  final Future<Map<String, dynamic>> Function(int customerId) rechargeOptions;
  final Future<Map<String, dynamic>> Function(int customerId) loadAdminProfile;
  final Future<Map<String, dynamic>> Function(String window) loadExpiry;
  final Future<Map<String, dynamic>> Function(int customerId, int planId)
      rechargePreview;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> request)
      recharge;
  final Future<void> Function() onLogout;
  final Future<bool> Function() onCheckForUpdates;

  const PanelWorkspace({
    super.key,
    required this.role,
    required this.name,
    required this.load,
    required this.loadTraffic,
    required this.trafficHistoryKey,
    required this.searchRecharge,
    required this.searchCustomers,
    required this.loadAdminOnus,
    required this.assignOnu,
    required this.unassignOnu,
    required this.removeOnu,
    required this.loadTickets,
    required this.ticketDetail,
    required this.createTicket,
    required this.updateTicket,
    required this.ticketNotifications,
    required this.readTicketNotification,
    required this.rechargeOptions,
    required this.loadAdminProfile,
    required this.loadExpiry,
    required this.rechargePreview,
    required this.recharge,
    required this.onLogout,
    required this.onCheckForUpdates,
  });

  @override
  State<PanelWorkspace> createState() => _PanelWorkspaceState();
}

class _PanelWorkspaceState extends State<PanelWorkspace> {
  int selected = 0;
  late Future<Map<String, dynamic>> pending;
  final customerSearch = TextEditingController();
  Timer? customerDebounce;
  Timer? ticketAlertTimer;
  int unreadAlerts = 0;
  bool alertsInitialized = false;
  bool alertsFetching = false;

  List<_Page> get pages => switch (widget.role) {
        'customer' => const [
            _Page('Home', 'home', Icons.home_outlined),
            _Page('Live', 'traffic', Icons.speed_outlined),
            _Page('Bills', 'sales', Icons.receipt_long_outlined),
            _Page('ONU', 'onus', Icons.router_outlined),
            _Page('Inbox', 'inbox', Icons.inbox_outlined),
            _Page('Support', 'support', Icons.support_agent_rounded),
            _Page('Alerts', 'alerts', Icons.notifications_rounded),
            _Page('Account', 'account', Icons.person_outline),
            _Page('More', 'more', Icons.grid_view_rounded),
          ],
        'reseller' => const [
            _Page('Overview', 'home', Icons.dashboard_outlined),
            _Page('Customers', 'customers', Icons.group_outlined),
            _Page('Sales', 'sales', Icons.receipt_long_outlined),
            _Page('ONU', 'onus', Icons.router_outlined),
            _Page('Account', 'account', Icons.person_outline),
            _Page('More', 'more', Icons.grid_view_rounded),
          ],
        _ => const [
            _Page('Overview', 'home', Icons.dashboard_outlined),
            _Page('Customers', 'customers', Icons.group_outlined),
            _Page('Resellers', 'resellers', Icons.groups_outlined),
            _Page('Sales', 'sales', Icons.receipt_long_outlined),
            _Page('Expiry', 'expiry', Icons.event_busy_outlined),
            _Page('Recharge', 'recharge', Icons.add_card_outlined),
            _Page('Support', 'support', Icons.support_agent_rounded),
            _Page('Alerts', 'alerts', Icons.notifications_rounded),
            _Page('ONU Manager', 'onu-admin', Icons.hub_rounded),
            _Page('More', 'more', Icons.apps_outlined),
          ],
      };

  List<String> get primarySections => switch (widget.role) {
        'customer' => const ['home', 'account'],
        'reseller' => const ['home', 'customers', 'sales', 'account'],
        _ => const ['home', 'customers', 'recharge', 'support'],
      };

  void openMore() {
    final index = pages.indexWhere((p) => p.section == 'more');
    if (index >= 0) change(index);
  }

  @override
  void initState() {
    super.initState();
    pending = widget.load('home');
    if (widget.role == 'customer' ||
        widget.role == 'admin' ||
        widget.role == 'superadmin') {
      WidgetsBinding.instance.addPostFrameCallback((_) => checkTicketAlerts());
      ticketAlertTimer = Timer.periodic(
          const Duration(seconds: 45), (_) => checkTicketAlerts());
    }
  }

  @override
  void dispose() {
    customerDebounce?.cancel();
    ticketAlertTimer?.cancel();
    customerSearch.dispose();
    super.dispose();
  }

  Future<void> checkTicketAlerts() async {
    if (!mounted || alertsFetching) return;
    alertsFetching = true;
    try {
      final data = await widget.ticketNotifications();
      final next = int.tryParse('${data['unread']}') ?? 0;
      if (mounted) {
        final increased = alertsInitialized && next > unreadAlerts;
        setState(() => unreadAlerts = next);
        alertsInitialized = true;
        if (increased) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('New support ticket activity. Check Alerts.')));
        }
      }
    } catch (_) {
      // Keep the rest of the app usable if tickets are unavailable.
    } finally {
      alertsFetching = false;
    }
  }

  void onCustomerQuery(String query) {
    customerDebounce?.cancel();
    customerDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && pages[selected].section == 'customers') {
        setState(() => pending = widget.searchCustomers(query));
      }
    });
  }

  void change(int index) {
    setState(() {
      selected = index;
      final section = pages[index].section;
      pending = (section == 'account' ||
              section == 'more' ||
              section == 'traffic' ||
              section == 'recharge' ||
              section == 'expiry' ||
              section == 'support' ||
              section == 'alerts' ||
              section == 'onu-admin')
          ? Future.value(<String, dynamic>{'available': true})
          : section == 'customers'
              ? widget.searchCustomers(customerSearch.text.trim())
              : widget.load(section);
    });
  }

  Future<void> refresh() async {
    final section = pages[selected].section;
    final next = section == 'customers'
        ? widget.searchCustomers(customerSearch.text.trim())
        : widget.load(section);
    setState(() => pending = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder renders the exact API error and exposes Retry.
    }
  }

  void openRecharge(String username) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Customer recharge')),
            body: AdminRechargePage(
                initialUsername: username,
                search: widget.searchRecharge,
                options: widget.rechargeOptions,
                preview: widget.rechargePreview,
                recharge: widget.recharge))));
  }

  void openCustomer(int id) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AdminCustomerProfilePage(
            customerId: id,
            load: widget.loadAdminProfile,
            onRecharge: openRecharge)));
  }

  @override
  Widget build(BuildContext context) {
    final page = pages[selected];
    return Scaffold(
      appBar: AppBar(
        title: Text('Arivo ISP Billing · ${page.title}'),
        actions: [
          if (widget.role == 'admin' || widget.role == 'superadmin')
            IconButton(
                tooltip: 'Support notifications',
                onPressed: () {
                  final index = pages.indexWhere((p) => p.section == 'alerts');
                  if (index >= 0) change(index);
                  checkTicketAlerts();
                },
                icon: unreadAlerts > 0
                    ? Badge.count(
                        count: unreadAlerts,
                        child: const Icon(Icons.notifications_active_rounded))
                    : const Icon(Icons.notifications_none_rounded)),
          IconButton(
            tooltip: 'Check for app updates',
            onPressed: () async {
              try {
                final found = await widget.onCheckForUpdates();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(found
                          ? 'Update found. Downloading securely in the background…'
                          : 'You have the latest app version.')));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Could not check for updates.')),
                  );
                }
              }
            },
            icon: const Icon(Icons.system_update_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: (page.section == 'account' ||
                    page.section == 'more' ||
                    page.section == 'traffic' ||
                    page.section == 'recharge' ||
                    page.section == 'expiry' ||
                    page.section == 'support' ||
                    page.section == 'alerts' ||
                    page.section == 'onu-admin')
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
        'more' => _MorePage(
            load: widget.load,
            otherPages: pages
                .where((p) =>
                    p.section != 'more' && !primarySections.contains(p.section))
                .toList(),
            onSelect: (section) {
              final index = pages.indexWhere((p) => p.section == section);
              if (index >= 0) change(index);
            },
            showAdminInventory:
                widget.role == 'admin' || widget.role == 'superadmin'),
        'recharge' => AdminRechargePage(
            search: widget.searchRecharge,
            options: widget.rechargeOptions,
            preview: widget.rechargePreview,
            recharge: widget.recharge),
        'support' => SupportTicketsPage(
            role: widget.role,
            load: widget.loadTickets,
            detail: widget.ticketDetail,
            create: widget.createTicket,
            update: widget.updateTicket),
        'alerts' => TicketNotificationsPage(
            load: widget.ticketNotifications,
            markRead: widget.readTicketNotification,
            onTicket: (id) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => SupportTicketDetailsPage(
                        ticketId: id,
                        role: widget.role,
                        load: widget.ticketDetail,
                        update: widget.updateTicket))),
          ),
        'onu-admin' => AdminOnuPage(
            load: widget.loadAdminOnus,
            searchCustomers: widget.searchCustomers,
            assign: widget.assignOnu,
            unassign: widget.unassignOnu,
            remove: widget.removeOnu),
        'expiry' => AdminExpiryPage(
            load: widget.loadExpiry, onCustomer: (id) => openCustomer(id)),
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
              return Column(children: [
                if (page.section == 'customers')
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: customerSearch,
                        onChanged: onCustomerQuery,
                        onSubmitted: (q) {
                          customerDebounce?.cancel();
                          setState(() => pending = widget.searchCustomers(q));
                        },
                        decoration: InputDecoration(
                          labelText: 'Search customers',
                          hintText: 'Name, username, PPPoE or phone',
                          prefixIcon: const Icon(Icons.manage_search_rounded),
                          suffixIcon: IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                customerSearch.clear();
                                customerDebounce?.cancel();
                                setState(
                                    () => pending = widget.searchCustomers(''));
                              },
                              icon: const Icon(Icons.clear_rounded)),
                        ),
                      )),
                Expanded(
                    child: RefreshIndicator(
                  onRefresh: refresh,
                  child: _SectionView(
                    section: page.section,
                    data: data,
                    unreadAlerts: unreadAlerts,
                    onOpenSection: widget.role == 'customer'
                        ? (section) {
                            final index =
                                pages.indexWhere((p) => p.section == section);
                            if (index >= 0) change(index);
                          }
                        : null,
                    onRecharge: (widget.role == 'admin' ||
                                widget.role == 'superadmin') &&
                            page.section == 'customers'
                        ? openRecharge
                        : null,
                    onProfile: (widget.role == 'admin' ||
                                widget.role == 'superadmin') &&
                            page.section == 'customers'
                        ? openCustomer
                        : null,
                  ),
                ))
              ]);
            },
          ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: !primarySections.contains(page.section)
            ? primarySections.length
            : primarySections.indexOf(page.section),
        onDestinationSelected: (index) {
          if (index == primarySections.length) {
            openMore();
            return;
          }
          final pageIndex =
              pages.indexWhere((p) => p.section == primarySections[index]);
          if (pageIndex >= 0) change(pageIndex);
        },
        destinations: [
          for (final section in primarySections)
            NavigationDestination(
                icon: Icon(pages.firstWhere((p) => p.section == section).icon),
                label: pages.firstWhere((p) => p.section == section).title),
          const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded), label: 'More'),
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
  final void Function(String username)? onRecharge;
  final void Function(int customerId)? onProfile;
  final ValueChanged<String>? onOpenSection;
  final int unreadAlerts;
  const _SectionView(
      {required this.section,
      required this.data,
      this.onRecharge,
      this.onProfile,
      this.onOpenSection,
      this.unreadAlerts = 0});

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
      elements.addAll(_homeCards(
        context,
        data,
        onOpenSection: onOpenSection,
        unreadAlerts: unreadAlerts,
      ));
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
            if (section == 'customers') {
              elements.add(_CustomerCompactCard(
                  customer: map,
                  onProfile: onProfile == null
                      ? null
                      : () => onProfile!(int.parse('${map['id']}')),
                  onRecharge: onRecharge == null || map['status'] != 'Active'
                      ? null
                      : () => onRecharge!('${map['username']}')));
            } else {
              elements
                  .add(_InfoCard(title: _rowTitle(map, section), values: map));
            }
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

  List<Widget> _homeCards(
    BuildContext context,
    Map<String, dynamic> data, {
    ValueChanged<String>? onOpenSection,
    int unreadAlerts = 0,
  }) {
    if (data['role'] == 'customer') {
      final profile = _asMap(data['profile']);
      final package = _asMap(data['package']);
      final network = _asMap(data['network']);
      network.remove('usage_download_bytes');
      network.remove('usage_upload_bytes');
      final monthly = _asMap(data['monthly_usage']);
      return [
        _CustomerStatusHero(profile: profile, package: package),
        const SizedBox(height: 12),
        _CustomerMetricGrid(
          package: package,
          monthly: monthly,
          network: network,
        ),
        if (onOpenSection != null) ...[
          const SizedBox(height: 14),
          _CustomerQuickActions(
            unreadAlerts: unreadAlerts,
            onOpen: onOpenSection,
          ),
        ],
        const SizedBox(height: 6),
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

class _CustomerStatusHero extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> package;
  const _CustomerStatusHero({required this.profile, required this.package});

  @override
  Widget build(BuildContext context) {
    final state = '${package['state'] ?? 'none'}';
    final active = state == 'active';
    final name = '${profile['name'] ?? profile['username'] ?? 'Customer'}';
    final username = '${profile['username'] ?? ''}';
    final tone =
        active ? const Color(0xFF008F73) : Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: tone.withValues(alpha: .14),
          child: Icon(
            active ? Icons.wifi_rounded : Icons.signal_wifi_off_rounded,
            color: tone,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                active
                    ? 'Internet service active'
                    : 'Internet service inactive',
                style: TextStyle(
                  color: tone,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                )),
            const SizedBox(height: 3),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
            if (username.isNotEmpty)
              Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        Icon(
          active ? Icons.verified_rounded : Icons.error_outline_rounded,
          color: tone,
        ),
      ]),
    );
  }
}

String _connectedForLabel(dynamic seconds, dynamic online) {
  if (online == false) return 'Offline';
  final raw =
      seconds is num ? seconds.toInt() : int.tryParse('${seconds ?? ''}');
  if (raw == null) return 'Unavailable';
  final safe = raw < 0 ? 0 : raw;
  final days = safe ~/ 86400;
  final hours = (safe % 86400) ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m';
  return '<1m';
}

class _CustomerMetricGrid extends StatelessWidget {
  final Map<String, dynamic> package;
  final Map<String, dynamic> monthly;
  final Map<String, dynamic> network;
  const _CustomerMetricGrid({
    required this.package,
    required this.monthly,
    required this.network,
  });

  @override
  Widget build(BuildContext context) {
    final days = package['days_remaining'];
    final total = monthly['available'] == true
        ? _usageGb(monthly['total_bytes'])
        : 'Unavailable';
    final price = package['price_bdt'];
    final onuRx = network['onu_rx_dbm'];
    final onuStatus = network['onu_status'];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _CustomerMetric(
          icon: Icons.inventory_2_rounded,
          label: 'Package',
          value: '${package['name'] ?? 'Unavailable'}',
          detail: price == null ? null : '৳$price',
        ),
        _CustomerMetric(
          icon: Icons.speed_rounded,
          label: 'Speed',
          value: '${package['speed'] ?? 'Unavailable'}',
        ),
        _CustomerMetric(
          icon: Icons.timer_outlined,
          label: 'Connected for',
          value: _connectedForLabel(
            network['connected_seconds'],
            network['pppoe_online'],
          ),
          detail: network['connected_since']?.toString(),
        ),
        _CustomerMetric(
          icon: Icons.event_available_rounded,
          label: 'Days left',
          value: days == null ? 'Unavailable' : '$days days',
          detail: package['expiration']?.toString(),
        ),
        _CustomerMetric(
          icon: Icons.data_usage_rounded,
          label: 'This month',
          value: total,
        ),
        _CustomerMetric(
          icon: Icons.router_rounded,
          label: 'ONU signal',
          value: onuRx == null ? 'Unavailable' : '$onuRx dBm',
          detail: onuStatus?.toString(),
        ),
        _CustomerMetric(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Account balance',
          value: package['balance_bdt'] == null
              ? 'See account'
              : '৳${package['balance_bdt']}',
        ),
      ],
    );
  }
}

class _CustomerMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  const _CustomerMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: .65),
              child: Icon(icon, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if (detail != null && detail!.isNotEmpty)
                  Text(detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
          ]),
        ),
      );
}

class _CustomerQuickActions extends StatelessWidget {
  final int unreadAlerts;
  final ValueChanged<String> onOpen;
  const _CustomerQuickActions({
    required this.unreadAlerts,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            _QuickAction(
              icon: Icons.monitor_heart_rounded,
              label: 'Live',
              onTap: () => onOpen('traffic'),
            ),
            _QuickAction(
              icon: Icons.receipt_long_rounded,
              label: 'Bills',
              onTap: () => onOpen('sales'),
            ),
            _QuickAction(
              icon: Icons.support_agent_rounded,
              label: 'Support',
              onTap: () => onOpen('support'),
            ),
            _QuickAction(
              icon: unreadAlerts > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              label: unreadAlerts > 0 ? 'Alerts $unreadAlerts' : 'Alerts',
              onTap: () => onOpen('alerts'),
            ),
          ]),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon),
                ),
                const SizedBox(height: 5),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium),
              ]),
            ),
          ),
        ),
      );
}

class _CustomerCompactCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback? onProfile;
  final VoidCallback? onRecharge;
  const _CustomerCompactCard(
      {required this.customer,
      required this.onProfile,
      required this.onRecharge});
  @override
  Widget build(BuildContext context) {
    final active = customer['status'] == 'Active';
    final color = active ? const Color(0xFF008F73) : const Color(0xFFB45309);
    return Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: .12),
                      child: Icon(Icons.person_rounded, color: color)),
                  title: Text('${customer['fullname'] ?? 'Customer'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('@${customer['username'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Chip(
                      avatar: Icon(
                          active
                              ? Icons.check_circle_rounded
                              : Icons.pause_circle_outline_rounded,
                          size: 15,
                          color: color),
                      label: Text('${customer['status'] ?? 'Unknown'}',
                          style: TextStyle(color: color, fontSize: 12))),
                  onTap: onProfile,
                ),
                if (onProfile != null || onRecharge != null)
                  Row(children: [
                    if (onProfile != null)
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: onProfile,
                              icon: const Icon(Icons.badge_outlined),
                              label: const Text('Details'))),
                    if (onProfile != null && onRecharge != null)
                      const SizedBox(width: 8),
                    if (onRecharge != null)
                      Expanded(
                          child: FilledButton.icon(
                              onPressed: onRecharge,
                              icon: const Icon(Icons.bolt_rounded),
                              label: const Text('Recharge'))),
                  ]),
              ],
            )));
  }
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
  final List<_Page> otherPages;
  final ValueChanged<String> onSelect;
  final bool showAdminInventory;
  const _MorePage(
      {required this.load,
      required this.otherPages,
      required this.onSelect,
      required this.showAdminInventory});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('More services',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          for (final p in otherPages)
            Card(
                child: ListTile(
                    leading: Icon(p.icon),
                    title: Text(p.title),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => onSelect(p.section))),
          if (showAdminInventory)
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
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
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
