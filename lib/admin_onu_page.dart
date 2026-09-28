import 'dart:async';

import 'package:flutter/material.dart';

typedef OnuLoader = Future<Map<String, dynamic>> Function(
    String query, String filter);
typedef CustomerSearch = Future<Map<String, dynamic>> Function(String query);
typedef OnuMutation = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> input);

class AdminOnuPage extends StatefulWidget {
  final OnuLoader load;
  final CustomerSearch searchCustomers;
  final OnuMutation assign;
  final OnuMutation unassign;
  final OnuMutation remove;
  const AdminOnuPage(
      {super.key,
      required this.load,
      required this.searchCustomers,
      required this.assign,
      required this.unassign,
      required this.remove});
  @override
  State<AdminOnuPage> createState() => _AdminOnuPageState();
}

class _AdminOnuPageState extends State<AdminOnuPage> {
  final search = TextEditingController();
  Timer? debounce;
  String filter = 'all';
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.load('', filter);
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void reload() =>
      setState(() => future = widget.load(search.text.trim(), filter));
  void query(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) reload();
    });
  }

  Future<void> mutate(
      Future<Map<String, dynamic>> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
      reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ONU action failed: $e')));
      }
    }
  }

  Future<void> assign(Map<String, dynamic> onu) async {
    final chosen = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _CustomerPicker(search: widget.searchCustomers));
    if (chosen == null || !mounted) return;
    final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Assign ONU'),
                    content: Text('Assign ${onu['mac_address']} to '
                        '${chosen['fullname']} (${chosen['username']})?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx, true),
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Assign')),
                    ])) ??
        false;
    if (!ok) return;
    await mutate(
        () => widget.assign({'onu_id': onu['id'], 'customer_id': chosen['id']}),
        'ONU assigned to ${chosen['username']}');
  }

  Future<void> unassign(Map<String, dynamic> onu) async {
    final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Remove customer assignment'),
                    content: Text('Unassign ${onu['mac_address']} from '
                        '${onu['customer_username']}?\n\nThe ONU will remain registered on the OLT.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton.tonalIcon(
                          onPressed: () => Navigator.pop(ctx, true),
                          icon: const Icon(Icons.link_off_rounded),
                          label: const Text('Unassign')),
                    ])) ??
        false;
    if (!ok) return;
    await mutate(
        () => widget.unassign(
            {'onu_id': onu['id'], 'expected_customer_id': onu['customer_id']}),
        'Customer assignment removed');
  }

  Future<void> removeFromOlt(Map<String, dynamic> onu) async {
    final confirm = TextEditingController();
    try {
      final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                      title: const Text('Remove ONU from OLT'),
                      content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Only an OFFLINE, unassigned ONU can be removed. '
                                'This changes the OLT configuration.'),
                            const SizedBox(height: 12),
                            Text(
                                'Type the MAC to confirm:\n${onu['mac_address']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                                controller: confirm,
                                decoration: const InputDecoration(
                                    labelText: 'Confirm ONU MAC',
                                    prefixIcon:
                                        Icon(Icons.warning_amber_rounded))),
                          ]),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove from OLT')),
                      ])) ??
          false;
      if (!ok || !mounted) return;
      if (confirm.text.trim().toUpperCase() !=
          '${onu['mac_address']}'.toUpperCase()) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('MAC confirmation did not match.')));
        return;
      }
      await mutate(
          () => widget.remove(
              {'onu_id': onu['id'], 'confirm_mac': confirm.text.trim()}),
          'ONU removal verified');
    } finally {
      confirm.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(children: [
              TextField(
                  controller: search,
                  onChanged: query,
                  onSubmitted: (_) => reload(),
                  decoration: InputDecoration(
                      labelText: 'Search ONU',
                      hintText: 'MAC, customer or OLT',
                      prefixIcon: const Icon(Icons.radar_rounded),
                      suffixIcon: IconButton(
                          onPressed: () {
                            search.clear();
                            reload();
                          },
                          icon: const Icon(Icons.clear_rounded)))),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                  initialValue: filter,
                  decoration: const InputDecoration(
                      labelText: 'ONU filter',
                      prefixIcon: Icon(Icons.tune_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All ONUs')),
                    DropdownMenuItem(
                        value: 'unassigned', child: Text('Unassigned')),
                    DropdownMenuItem(
                        value: 'assigned', child: Text('Assigned')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'offline', child: Text('Offline')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => filter = v);
                      reload();
                    }
                  }),
            ])),
        Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
                future: future,
                builder: (context, result) {
                  if (result.hasError) {
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off_rounded, size: 42),
                      const SizedBox(height: 8),
                      Text('ONU inventory unavailable\n${result.error}',
                          textAlign: TextAlign.center),
                      FilledButton.icon(
                          onPressed: reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'))
                    ]));
                  }
                  if (!result.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = (result.data!['items'] as List? ?? [])
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                  return RefreshIndicator(
                      onRefresh: () async {
                        final next = widget.load(search.text.trim(), filter);
                        setState(() => future = next);
                        await next;
                      },
                      child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Row(children: [
                              const Icon(Icons.hub_rounded),
                              const SizedBox(width: 8),
                              Text('${rows.length} ONU',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ]),
                            const SizedBox(height: 8),
                            if (rows.isEmpty)
                              const Card(
                                  child: ListTile(
                                      leading: Icon(Icons.search_off_rounded),
                                      title: Text('No matching ONU'))),
                            for (final onu in rows)
                              _OnuCard(
                                  onu: onu,
                                  onAssign: onu['assigned'] == true ||
                                          onu['status'] == 'REMOVED'
                                      ? null
                                      : () => assign(onu),
                                  onUnassign: onu['assigned'] == true
                                      ? () => unassign(onu)
                                      : null,
                                  onRemove: onu['can_remove_from_olt'] == true
                                      ? () => removeFromOlt(onu)
                                      : null),
                            const SizedBox(height: 8),
                            Text('${result.data!['note'] ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]));
                }))
      ]);
}

class _OnuCard extends StatelessWidget {
  final Map<String, dynamic> onu;
  final VoidCallback? onAssign;
  final VoidCallback? onUnassign;
  final VoidCallback? onRemove;
  const _OnuCard(
      {required this.onu, this.onAssign, this.onUnassign, this.onRemove});
  @override
  Widget build(BuildContext context) {
    final status = '${onu['status'] ?? 'UNKNOWN'}';
    final online = status == 'ONLINE';
    final removed = status == 'REMOVED';
    final icon = removed
        ? Icons.delete_sweep_rounded
        : online
            ? Icons.wifi_tethering_rounded
            : Icons.wifi_tethering_off_rounded;
    final tone = removed
        ? Theme.of(context).colorScheme.error
        : online
            ? const Color(0xFF008F73)
            : const Color(0xFFB45309);
    final assigned = onu['assigned'] == true;
    return Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    backgroundColor: tone.withValues(alpha: .12),
                    child: Icon(icon, color: tone)),
                title: Text('PON 1/${onu['pon_port']} · ONU ${onu['onu_id']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    Text('${onu['mac_address']}\n${onu['olt_name'] ?? 'OLT'}'),
                trailing: Chip(
                    avatar: Icon(
                        online
                            ? Icons.check_circle_rounded
                            : removed
                                ? Icons.delete_outline_rounded
                                : Icons.pause_circle_rounded,
                        size: 15,
                        color: tone),
                    label: Text(status,
                        style: TextStyle(color: tone, fontSize: 11))),
              ),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(
                        assigned
                            ? Icons.person_pin_circle_rounded
                            : Icons.person_off_rounded,
                        size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            assigned
                                ? '${onu['customer_name'] ?? onu['customer_username']} · ${onu['customer_username']}'
                                : 'Unassigned ONU',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    if (onu['rx_power'] != null)
                      Text('RX ${onu['rx_power']} dBm',
                          style: Theme.of(context).textTheme.bodySmall),
                  ])),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (onAssign != null)
                  FilledButton.icon(
                      onPressed: onAssign,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Assign')),
                if (onUnassign != null)
                  OutlinedButton.icon(
                      onPressed: onUnassign,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Unassign')),
                if (onRemove != null)
                  OutlinedButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Remove from OLT')),
              ]),
            ])));
  }
}

class _CustomerPicker extends StatefulWidget {
  final CustomerSearch search;
  const _CustomerPicker({required this.search});
  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final query = TextEditingController();
  Future<Map<String, dynamic>>? future;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void run() {
    final q = query.text.trim();
    if (q.isEmpty) return;
    setState(() => future = widget.search(q));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Assign to customer'),
        content: SizedBox(
            width: 520,
            height: 390,
            child: Column(children: [
              TextField(
                  controller: query,
                  onSubmitted: (_) => run(),
                  decoration: InputDecoration(
                      labelText: 'Search customer',
                      hintText: 'Name, username, PPPoE or phone',
                      prefixIcon: const Icon(Icons.manage_search_rounded),
                      suffixIcon: IconButton(
                          onPressed: run,
                          icon: const Icon(Icons.search_rounded)))),
              const SizedBox(height: 10),
              Expanded(
                  child: future == null
                      ? const Center(child: Text('Search for a customer'))
                      : FutureBuilder<Map<String, dynamic>>(
                          future: future,
                          builder: (context, result) {
                            if (result.hasError) {
                              return Center(
                                  child:
                                      Text('Search failed: ${result.error}'));
                            }
                            if (!result.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final rows = (result.data!['items'] as List? ?? [])
                                .whereType<Map>()
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();
                            if (rows.isEmpty) {
                              return const Center(
                                  child: Text('No customer found'));
                            }
                            return ListView.builder(
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final c = rows[index];
                                  return Card(
                                      child: ListTile(
                                          leading: const CircleAvatar(
                                              child:
                                                  Icon(Icons.person_rounded)),
                                          title: Text(
                                              '${c['fullname'] ?? c['username']}'),
                                          subtitle: Text(
                                              '${c['username']} · ${c['status'] ?? ''}'),
                                          trailing: const Icon(
                                              Icons.chevron_right_rounded),
                                          onTap: () =>
                                              Navigator.pop(context, c)));
                                });
                          })),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))
        ],
      );
}
