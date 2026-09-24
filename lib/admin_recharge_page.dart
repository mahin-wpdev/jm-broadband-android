import 'dart:math';
import 'package:flutter/material.dart';

/// Only the admin tab can reach this page; the PHP API repeats role checks.
class AdminRechargePage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String query) search;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)
      recharge;
  final Future<Map<String, dynamic>> Function(int customerId) options;
  final String? initialUsername;
  const AdminRechargePage({
    super.key,
    required this.search,
    required this.recharge,
    required this.options,
    this.initialUsername,
  });

  @override
  State<AdminRechargePage> createState() => _AdminRechargePageState();
}

class _AdminRechargePageState extends State<AdminRechargePage> {
  final searchInput = TextEditingController();
  List<Map<String, dynamic>> matches = [];
  Map<String, dynamic>? selected;
  List<Map<String, dynamic>> plans = [];
  int? chosenPlanId;
  String? requestKey;
  String? error;
  String? success;
  bool loading = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final username = widget.initialUsername;
    if (username != null && username.isNotEmpty) {
      searchInput.text = username;
      WidgetsBinding.instance.addPostFrameCallback((_) => findCustomer());
    }
  }

  @override
  void dispose() {
    searchInput.dispose();
    super.dispose();
  }

  String newRequestKey() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> findCustomer() async {
    final q = searchInput.text.trim();
    if (q.length < 2 || loading || busy) return;
    setState(() {
      selected = null;
      plans = [];
      chosenPlanId = null;
      requestKey = null;
      matches = [];
      loading = true;
      error = null;
      success = null;
    });
    try {
      final result = await widget.search(q);
      if (!mounted) return;
      final rows = result['items'] as List? ?? [];
      setState(() {
        matches = rows
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      });
      if (widget.initialUsername != null) {
        for (final match in matches) {
          if (match['username'] == widget.initialUsername &&
              match['can_recharge'] == true) {
            await selectCustomer(match);
            break;
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> selectCustomer(Map<String, dynamic> row) async {
    if (busy) return;
    setState(() {
      selected = null;
      plans = [];
      chosenPlanId = null;
      requestKey = null;
      loading = true;
      error = null;
      success = null;
    });
    try {
      final response = await widget.options(int.parse('${row['id']}'));
      if (!mounted) return;
      final customer = Map<String, dynamic>.from(response['customer'] as Map);
      final eligible = ((response['items'] as List?) ?? [])
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
      if (eligible.isEmpty) {
        throw StateError('No compatible active packages available');
      }
      setState(() {
        selected = customer;
        plans = eligible;
        chosenPlanId =
            eligible.any((p) => '${p['id']}' == '${customer['plan_id']}')
                ? int.parse('${customer['plan_id']}')
                : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> confirmRecharge(
      Map<String, dynamic> user, Map<String, dynamic> package) async {
    String password = '';
    String confirmation = '';
    bool verified = false;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Confirm manual recharge'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Customer: ${user['username']}'),
              Text('Current plan: ${user['name_plan']}'),
              Text('Selected plan: ${package['name_plan']}'),
              Text('Router: ${user['routers']}'),
              Text('Selected package price: ৳${package['price']}'),
              const SizedBox(height: 12),
              const Text('This renews service, records an invoice and '
                  'can mark additional bills paid in phpNuxBill. '
                  'It does NOT collect or verify a bKash/Nagad payment. '
                  'Check the amount and payment independently.'),
              TextField(
                onChanged: (value) => update(() => confirmation = value.trim()),
                decoration: const InputDecoration(
                  labelText: 'Type the customer username to confirm',
                ),
              ),
              CheckboxListTile(
                value: verified,
                onChanged: (value) => update(() => verified = value == true),
                title: const Text('I have verified payment outside the app'),
              ),
              TextField(
                onChanged: (value) => update(() => password = value),
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm admin password',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: !verified || confirmation != user['username']
                  ? null
                  : () {
                      if (password.isNotEmpty) {
                        Navigator.pop(dialogContext, password);
                      }
                    },
              child: const Text('Recharge now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> submit() async {
    final customer = selected;
    final package = plans
        .where((p) => int.tryParse('${p['id']}') == chosenPlanId)
        .firstOrNull;
    if (customer == null || package == null || busy) return;
    final password = await confirmRecharge(customer, package);
    if (password == null || !mounted) return;
    requestKey ??= newRequestKey();
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      final result = await widget.recharge({
        'customer_id': customer['id'],
        'username': customer['username'],
        'plan_id': chosenPlanId,
        'expected_plan_id': customer['plan_id'],
        'request_key': requestKey,
        'admin_password': password,
        'payment_verified': true,
      });
      if (!mounted) return;
      setState(() {
        success = 'Recharged ${customer['username']}. '
            'Invoice: ${result['invoice']}.';
        matches = [];
        selected = null;
        plans = [];
        chosenPlanId = null;
        requestKey = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e. If the connection timed out, '
            'check the Panel transaction before trying again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('Admin manual recharge',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Search any customer by username or name. '
              'Customer and reseller accounts cannot use this action.'),
          TextField(
            controller: searchInput,
            onSubmitted: (_) => findCustomer(),
            decoration: const InputDecoration(
              labelText: 'Customer username or name',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: loading || busy ? null : findCustomer,
            child: Text(loading ? 'Searching…' : 'Search customers'),
          ),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (success != null)
            Text(success!, style: const TextStyle(color: Colors.green)),
          if (selected != null)
            Card(
                child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text('Selected: ${selected!['fullname']} '
                    '(${selected!['username']})'),
                Text('Current: ${selected!['name_plan']} · '
                    '৳${selected!['price']}'),
                DropdownButtonFormField<int>(
                  key: ValueKey(selected!['id']),
                  initialValue: chosenPlanId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Recharge package'),
                  items: [
                    for (final plan in plans)
                      DropdownMenuItem<int>(
                        value: int.parse('${plan['id']}'),
                        child: Text('${plan['name_plan']} · ৳${plan['price']}'),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                            chosenPlanId = value;
                            requestKey = null;
                          }),
                ),
                const Text(
                    'Changing package and renewal happen in one recharge. '
                    'Verify total invoice, tax and other bills in the Panel.'),
                FilledButton.icon(
                  onPressed: busy || chosenPlanId == null ? null : submit,
                  icon: const Icon(Icons.payment),
                  label: Text(busy ? 'Processing…' : 'Review & recharge'),
                ),
              ]),
            )),
          Expanded(
              child: ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, i) {
              final user = matches[i];
              final eligible = user['can_recharge'] == true;
              return Card(
                  child: ListTile(
                title: Text('${user['fullname']} '
                    '(${user['username']})'),
                subtitle: Text(eligible
                    ? '${user['name_plan']} · ${user['routers']} · '
                        '৳${user['price']}'
                    : 'No existing plan or account inactive'),
                enabled: eligible && !busy && !loading,
                selected: selected?['id'] == user['id'],
                trailing: FilledButton(
                  onPressed: eligible && !busy && !loading
                      ? () => selectCustomer(user)
                      : null,
                  child: const Text('Recharge'),
                ),
                onTap: eligible && !busy && !loading
                    ? () => selectCustomer(user)
                    : null,
              ));
            },
          )),
        ]),
      );
}
