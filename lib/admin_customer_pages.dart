import 'package:flutter/material.dart';

/// Read-only account overview, restricted by the PHP API to Admin/SuperAdmin.
class AdminCustomerProfilePage extends StatefulWidget {
  final int customerId;
  final Future<Map<String, dynamic>> Function(int) load;
  final void Function(String username) onRecharge;
  const AdminCustomerProfilePage(
      {super.key,
      required this.customerId,
      required this.load,
      required this.onRecharge});
  @override
  State<AdminCustomerProfilePage> createState() => _AdminCustomerProfileState();
}

class _AdminCustomerProfileState extends State<AdminCustomerProfilePage> {
  late Future<Map<String, dynamic>> pending;
  @override
  void initState() {
    super.initState();
    pending = widget.load(widget.customerId);
  }

  void reload() => setState(() => pending = widget.load(widget.customerId));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Customer profile'), actions: [
        IconButton(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh profile')
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
          future: pending,
          builder: (context, result) {
            if (result.hasError) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Unable to load customer profile'),
                Text('${result.error}'),
                FilledButton(onPressed: reload, child: const Text('Retry'))
              ]));
            }
            if (!result.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = result.data!;
            final c = Map<String, dynamic>.from(data['customer'] as Map);
            final transactions = (data['transactions'] as List? ?? [])
                .whereType<Map>()
                .map((v) => Map<String, dynamic>.from(v))
                .toList();
            final requests = (data['admin_recharge_requests'] as List? ?? [])
                .whereType<Map>()
                .map((v) => Map<String, dynamic>.from(v))
                .toList();
            final usage =
                Map<String, dynamic>.from(data['monthly_usage'] as Map? ?? {});
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${c['fullname']} · ${c['username']}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: c['status'] == 'Active'
                      ? () => widget.onRecharge('${c['username']}')
                      : null,
                  icon: const Icon(Icons.add_card),
                  label: const Text('Recharge / change package')),
              _details('Account', {
                'Status': c['status'],
                'Phone': c['phonenumber'],
                'Address': c['address'],
                'PPPoE': c['pppoe_username'],
                'Balance BDT': c['balance']
              }),
              _details('Current internet plan', {
                'Package': c['name_plan'] ?? c['namebp'],
                'Package price BDT': c['price'],
                'Service status': c['service_status'],
                'Router': c['routers'],
                'Expiry date': c['expiration'],
                'Expiry time': c['time'],
              }),
              _details('Monthly usage (RADIUS)', {
                'Download GB': usage['download_gb'],
                'Upload GB': usage['upload_gb'],
                'Total GB': usage['total_gb'],
                'Note': usage['note']
              }),
              if (data['onu'] is Map)
                _details('Last synced ONU',
                    Map<String, dynamic>.from(data['onu'] as Map)),
              Text('Recorded transaction history',
                  style: Theme.of(context).textTheme.titleLarge),
              if (transactions.isEmpty) const Text('No recorded transactions'),
              for (final t in transactions)
                Card(
                    child: ListTile(
                        title: Text('${t['invoice']} · ${t['plan_name']}'),
                        subtitle: Text('${t['recharged_on']} · ${t['method']}\n'
                            'Expiry: ${t['expiration']} · Router: ${t['routers']}'),
                        trailing: Text('৳${t['price']}'))),
              const SizedBox(height: 12),
              Text('Mobile admin recharge audit',
                  style: Theme.of(context).textTheme.titleLarge),
              if (requests.isEmpty)
                const Text('No mobile admin recharge records'),
              for (final r in requests)
                Card(
                    child: ListTile(
                        title: Text(
                            '${r['status']} · ${r['invoice'] ?? 'No invoice'}'),
                        subtitle: Text(
                            '${r['created_at']} · ${r['admin_username'] ?? 'Unknown admin'}'
                            '\n${r['name_plan'] ?? 'Plan unavailable'}'))),
              const SizedBox(height: 8),
              Text('${data['note'] ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall),
            ]);
          }));
}

Widget _details(String title, Map<String, dynamic> fields) => Card(
    child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          for (final field in fields.entries)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${field.key}: ${field.value ?? 'Unavailable'}')),
        ])));

/// Expiring customer dashboard. No customer/reseller can request this endpoint.
class AdminExpiryPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String window) load;
  final void Function(int customerId) onCustomer;
  const AdminExpiryPage(
      {super.key, required this.load, required this.onCustomer});
  @override
  State<AdminExpiryPage> createState() => _AdminExpiryPageState();
}

class _AdminExpiryPageState extends State<AdminExpiryPage> {
  String window = 'today';
  late Future<Map<String, dynamic>> pending;
  @override
  void initState() {
    super.initState();
    pending = widget.load(window);
  }

  void choose(String next) => setState(() {
        window = next;
        pending = widget.load(window);
      });
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: window,
              decoration: const InputDecoration(labelText: 'Expiry period'),
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: '3', child: Text('Next 3 days')),
                DropdownMenuItem(value: '7', child: Text('Next 7 days')),
                DropdownMenuItem(value: 'overdue', child: Text('Past expiry')),
              ],
              onChanged: (v) {
                if (v != null) choose(v);
              },
            )),
        Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
                future: pending,
                builder: (context, result) {
                  if (result.hasError) {
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Expiry data unavailable'),
                      Text('${result.error}'),
                      FilledButton(
                          onPressed: () => choose(window),
                          child: const Text('Retry'))
                    ]));
                  }
                  if (!result.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = result.data!;
                  final rows = (data['items'] as List? ?? [])
                      .whereType<Map>()
                      .map((v) => Map<String, dynamic>.from(v))
                      .toList();
                  return RefreshIndicator(
                      onRefresh: () async {
                        final next = widget.load(window);
                        setState(() => pending = next);
                        try {
                          await next;
                        } catch (_) {}
                      },
                      child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Text('Customers: ${data['count'] ?? rows.length}',
                                style: Theme.of(context).textTheme.titleLarge),
                            if (data['truncated'] == true)
                              const Text(
                                  'Showing first 150 customers; refine in Panel for full list.'),
                            if (rows.isEmpty)
                              const ListTile(
                                  title: Text('No customers in this period')),
                            for (final c in rows)
                              Card(
                                  child: ListTile(
                                title:
                                    Text('${c['fullname']} (${c['username']})'),
                                subtitle:
                                    Text('${c['name_plan'] ?? c['namebp']} · '
                                        '${c['expiration']} ${c['time']}'),
                                trailing: IconButton(
                                    tooltip: 'Open customer profile',
                                    onPressed: () => widget
                                        .onCustomer(int.parse('${c['id']}')),
                                    icon: const Icon(Icons.chevron_right)),
                                onTap: () =>
                                    widget.onCustomer(int.parse('${c['id']}')),
                              )),
                            Text('${data['note'] ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]));
                }))
      ]);
}
