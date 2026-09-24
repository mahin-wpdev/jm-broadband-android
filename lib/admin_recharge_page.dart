import 'dart:math';
import 'package:flutter/material.dart';

/// Only the admin tab can reach this page; the PHP API repeats role checks.
class AdminRechargePage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String query) search;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)
      recharge;
  const AdminRechargePage({
    super.key,
    required this.search,
    required this.recharge,
  });

  @override
  State<AdminRechargePage> createState() => _AdminRechargePageState();
}

class _AdminRechargePageState extends State<AdminRechargePage> {
  final searchInput = TextEditingController();
  List<Map<String, dynamic>> matches = [];
  Map<String, dynamic>? selected;
  String? requestKey;
  String? error;
  String? success;
  bool loading = false;
  bool busy = false;
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
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> confirmRecharge(Map<String, dynamic> user) async {
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
              Text('Plan: ${user['name_plan']}'),
              Text('Router: ${user['routers']}'),
              Text('Package price: ৳${user['price']}'),
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
    if (customer == null || busy) return;
    final password = await confirmRecharge(customer);
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
                Text('${selected!['name_plan']} · '
                    '৳${selected!['price']}'),
                FilledButton.icon(
                  onPressed: busy ? null : submit,
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
                enabled: eligible && !busy,
                selected: selected?['id'] == user['id'],
                onTap: !eligible || busy
                    ? null
                    : () => setState(() {
                          selected = user;
                          requestKey = null;
                          error = null;
                          success = null;
                        }),
              ));
            },
          )),
        ]),
      );
}
