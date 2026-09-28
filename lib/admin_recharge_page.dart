import 'dart:math';
import 'package:flutter/material.dart';

/// Only the admin tab can reach this page; the PHP API repeats role checks.
class AdminRechargePage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String query) search;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)
      recharge;
  final Future<Map<String, dynamic>> Function(int customerId) options;
  final Future<Map<String, dynamic>> Function(int customerId, int planId)
      preview;
  final String? initialUsername;
  const AdminRechargePage({
    super.key,
    required this.search,
    required this.recharge,
    required this.options,
    required this.preview,
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
  Map<String, dynamic>? previewDetails;
  bool previewLoading = false;
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
      previewDetails = null;
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

  Future<void> loadPreview(int customerId, int planId) async {
    setState(() {
      previewDetails = null;
      previewLoading = true;
      error = null;
    });
    try {
      final response = await widget.preview(customerId, planId);
      if (!mounted ||
          selected == null ||
          int.tryParse('${selected!['id']}') != customerId ||
          chosenPlanId != planId) {
        return;
      }
      setState(() => previewDetails =
          Map<String, dynamic>.from(response['preview'] as Map));
    } catch (e) {
      if (mounted && chosenPlanId == planId) {
        setState(() => error = 'Preview unavailable: $e');
      }
    } finally {
      if (mounted && chosenPlanId == planId) {
        setState(() => previewLoading = false);
      }
    }
  }

  Future<void> selectCustomer(Map<String, dynamic> row) async {
    if (busy) return;
    setState(() {
      selected = null;
      plans = [];
      previewDetails = null;
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
      if (chosenPlanId != null) {
        await loadPreview(int.parse('${customer['id']}'), chosenPlanId!);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> confirmRecharge(
      Map<String, dynamic> user, Map<String, dynamic> package) async {
    bool confirmed = false;
    return (await showDialog<bool>(
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
                  Text(
                      'Additional bills: ৳${previewDetails!['additional_bills_bdt']}'),
                  if (previewDetails!['period_invoice_override_bdt'] != null)
                    Text(
                        'Period invoice base: ৳${previewDetails!['period_invoice_override_bdt']}'),
                  Text(
                      'Expected recorded amount: ৳${previewDetails!['expected_recorded_amount_bdt']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${previewDetails!['note']}'),
                  const SizedBox(height: 12),
                  const Text('This renews service, records an invoice and '
                      'can mark additional bills paid in phpNuxBill. '
                      'It does NOT collect or verify a bKash/Nagad payment. '
                      'Check the amount and payment independently.'),
                  CheckboxListTile(
                    value: confirmed,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) =>
                        update(() => confirmed = value == true),
                    title: const Text(
                        'I confirm the customer/package details and have verified payment outside the app'),
                    subtitle: Text(
                        '${user['fullname']} (${user['username']}) · ${package['name_plan']} · ৳${previewDetails!['expected_recorded_amount_bdt']}'),
                  ),
                  if (!confirmed)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tick the confirmation to enable Recharge now.',
                        style: TextStyle(fontSize: 12),
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
                  onPressed: !confirmed
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Recharge now'),
                ),
              ],
            ),
          ),
        )) ??
        false;
  }

  Widget _successLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Future<void> showRechargeSuccess(
    Map<String, dynamic> customer,
    Map<String, dynamic> selectedPackage,
    Map<String, dynamic> result,
    Map<String, dynamic> preview,
  ) async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Recharge successful',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              color: Theme.of(dialogContext).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 28,
                  offset: Offset(0, 12),
                  color: Color(0x33000000),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: const CircleAvatar(
                    radius: 38,
                    backgroundColor: Color(0xFFE7F7ED),
                    child: Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: Color(0xFF168A45),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Recharge successful',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${customer['fullname']} (${customer['username']})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _successLine('Package', '${selectedPackage['name_plan']}'),
                _successLine(
                  'Amount',
                  '৳${preview['expected_recorded_amount_bdt']}',
                ),
                _successLine('Invoice', '${result['invoice'] ?? '-'}'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.done_rounded),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: .92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> submit() async {
    final customer = selected;
    final package = plans
        .where((p) => int.tryParse('${p['id']}') == chosenPlanId)
        .firstOrNull;
    if (customer == null ||
        package == null ||
        previewDetails == null ||
        previewLoading ||
        busy) {
      return;
    }
    final confirmed = await confirmRecharge(customer, package);
    if (!confirmed || !mounted) return;
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
        'expected_preview_amount':
            previewDetails!['expected_recorded_amount_bdt'],
        'request_key': requestKey,
        'payment_verified': true,
      });
      if (!mounted) return;
      final previewSnapshot = Map<String, dynamic>.from(previewDetails!);
      await showRechargeSuccess(customer, package, result, previewSnapshot);
      if (!mounted) return;
      setState(() {
        success = null;
        matches = [];
        selected = null;
        plans = [];
        previewDetails = null;
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
                      : (value) {
                          setState(() {
                            chosenPlanId = value;
                            previewDetails = null;
                            requestKey = null;
                          });
                          if (value != null) {
                            loadPreview(int.parse('${selected!['id']}'), value);
                          }
                        },
                ),
                if (previewLoading) const LinearProgressIndicator(),
                if (previewDetails != null)
                  Column(children: [
                    Text('Package: ৳${previewDetails!['package_price_bdt']}'),
                    Text(
                        'Additional bills: ৳${previewDetails!['additional_bills_bdt']}'),
                    if (previewDetails!['period_invoice_override_bdt'] != null)
                      Text(
                          'Period invoice base: ৳${previewDetails!['period_invoice_override_bdt']}'),
                    Text(
                        'Expected recorded amount: ৳${previewDetails!['expected_recorded_amount_bdt']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${previewDetails!['note']}'),
                  ]),
                FilledButton.icon(
                  onPressed: busy ||
                          chosenPlanId == null ||
                          previewLoading ||
                          previewDetails == null
                      ? null
                      : submit,
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
