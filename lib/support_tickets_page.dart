import 'package:flutter/material.dart';

typedef TicketLoad = Future<Map<String, dynamic>> Function();
typedef TicketDetail = Future<Map<String, dynamic>> Function(int id);
typedef TicketAction = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> input);

class SupportTicketsPage extends StatefulWidget {
  final String role;
  final TicketLoad load;
  final TicketDetail detail;
  final TicketAction create;
  final TicketAction update;
  const SupportTicketsPage(
      {super.key,
      required this.role,
      required this.load,
      required this.detail,
      required this.create,
      required this.update});
  @override
  State<SupportTicketsPage> createState() => _SupportTicketsState();
}

class _SupportTicketsState extends State<SupportTicketsPage> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  void reload() => setState(() => future = widget.load());
  Future<void> open(int id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SupportTicketDetailsPage(
            ticketId: id,
            role: widget.role,
            load: widget.detail,
            update: widget.update)));
    if (mounted) reload();
  }

  Future<void> create() async {
    final subject = TextEditingController();
    final description = TextEditingController();
    var category = 'no_internet';
    var busy = false;
    String? error;
    try {
      final done = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, setDialog) => AlertDialog(
                      title: const Text('New support ticket'),
                      content: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration:
                                const InputDecoration(labelText: 'Category'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'no_internet',
                                  child: Text('No internet')),
                              DropdownMenuItem(
                                  value: 'slow_speed',
                                  child: Text('Slow speed')),
                              DropdownMenuItem(
                                  value: 'los',
                                  child: Text('LOS / optical signal')),
                              DropdownMenuItem(
                                  value: 'billing', child: Text('Billing')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('Other')),
                            ],
                            onChanged: (v) {
                              if (v != null) setDialog(() => category = v);
                            }),
                        TextField(
                            controller: subject,
                            maxLength: 120,
                            decoration:
                                const InputDecoration(labelText: 'Subject')),
                        TextField(
                            controller: description,
                            maxLines: 4,
                            maxLength: 3000,
                            decoration: const InputDecoration(
                                labelText: 'What happened?')),
                        if (error != null)
                          Text(error!,
                              style: const TextStyle(color: Colors.red)),
                      ])),
                      actions: [
                        TextButton(
                            onPressed:
                                busy ? null : () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    setDialog(() => busy = true);
                                    try {
                                      await widget.create({
                                        'category': category,
                                        'subject': subject.text,
                                        'description': description.text
                                      });
                                      if (ctx.mounted) Navigator.pop(ctx, true);
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setDialog(() => error = '$e');
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialog(() => busy = false);
                                      }
                                    }
                                  },
                            child: Text(busy ? 'Sending…' : 'Submit ticket'))
                      ])));
      if (done == true && mounted) reload();
    } finally {
      subject.dispose();
      description.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        if (widget.role == 'customer')
          Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: create,
                      icon: const Icon(Icons.add_comment_rounded),
                      label: const Text('Open support ticket')))),
        Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
                future: future,
                builder: (context, result) {
                  if (result.hasError) {
                    return Center(
                        child: Text('Ticket list error: ${result.error}'));
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
                        reload();
                        await future;
                      },
                      child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (rows.isEmpty)
                              const ListTile(title: Text('No support tickets')),
                            for (final t in rows)
                              Card(
                                  child: ListTile(
                                      leading: const CircleAvatar(
                                          child: Icon(
                                              Icons.support_agent_rounded)),
                                      title: Text(
                                          '#${t['id']} · ${t['subject']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      subtitle: Text(
                                          '${t['category']} · ${t['updated_at']}'
                                          '${widget.role == 'admin' ? ' · ${t['username']}' : ''}'),
                                      trailing:
                                          Chip(label: Text('${t['status']}')),
                                      onTap: () =>
                                          open(int.parse('${t['id']}'))))
                          ]));
                }))
      ]);
}

class SupportTicketDetailsPage extends StatefulWidget {
  final int ticketId;
  final String role;
  final TicketDetail load;
  final TicketAction update;
  const SupportTicketDetailsPage(
      {super.key,
      required this.ticketId,
      required this.role,
      required this.load,
      required this.update});
  @override
  State<SupportTicketDetailsPage> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<SupportTicketDetailsPage> {
  late Future<Map<String, dynamic>> future;
  final reply = TextEditingController();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    future = widget.load(widget.ticketId);
  }

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  void reload() => setState(() => future = widget.load(widget.ticketId));
  Future<void> submit(Map<String, dynamic> input) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.update({'ticket_id': widget.ticketId, ...input});
      reply.clear();
      if (mounted) reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ticket update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Ticket #${widget.ticketId}'), actions: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded))
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, result) {
            if (result.hasError) return Center(child: Text('${result.error}'));
            if (!result.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final t = Map<String, dynamic>.from(result.data!['ticket'] as Map);
            final events = (result.data!['events'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${t['subject']}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('${t['category']} · ${t['status']}'),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('${t['description']}'))),
              if (widget.role == 'admin')
                DropdownButtonFormField<String>(
                    key: ValueKey(t['status']),
                    initialValue: '${t['status']}',
                    decoration:
                        const InputDecoration(labelText: 'Ticket status'),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(
                          value: 'in_progress', child: Text('In progress')),
                      DropdownMenuItem(
                          value: 'resolved', child: Text('Resolved')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null && v != t['status']) {
                              submit({'action': 'status', 'status': v});
                            }
                          }),
              const SizedBox(height: 12),
              Text('Conversation',
                  style: Theme.of(context).textTheme.titleLarge),
              for (final e in events)
                Card(
                    child: ListTile(
                        leading: Icon(e['actor_type'] == 'staff'
                            ? Icons.admin_panel_settings_rounded
                            : Icons.person_rounded),
                        title: Text('${e['event_type']} · ${e['actor_type']}'),
                        subtitle: Text('${e['message']}\n${e['created_at']}'))),
              if (t['status'] != 'closed') ...[
                TextField(
                    controller: reply,
                    maxLines: 3,
                    maxLength: 3000,
                    decoration: const InputDecoration(
                        labelText: 'Reply',
                        prefixIcon: Icon(Icons.chat_bubble_outline))),
                FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () =>
                            submit({'action': 'reply', 'message': reply.text}),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(busy ? 'Sending…' : 'Send reply')),
              ]
            ]);
          }));
}

class TicketNotificationsPage extends StatefulWidget {
  final TicketLoad load;
  final Future<Map<String, dynamic>> Function(int notificationId) markRead;
  final void Function(int ticketId) onTicket;
  const TicketNotificationsPage(
      {super.key,
      required this.load,
      required this.markRead,
      required this.onTicket});
  @override
  State<TicketNotificationsPage> createState() => _TicketNotificationsState();
}

class _TicketNotificationsState extends State<TicketNotificationsPage> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  void reload() => setState(() => future = widget.load());
  Future<void> open(Map<String, dynamic> n) async {
    try {
      await widget.markRead(int.parse('${n['id']}'));
      if (mounted) {
        widget.onTicket(int.parse('${n['ticket_id']}'));
        reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open alert: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, result) {
        if (result.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Alerts unavailable: ${result.error}'),
            FilledButton(onPressed: reload, child: const Text('Retry'))
          ]));
        }
        if (!result.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = result.data!;
        final items = (data['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return RefreshIndicator(
            onRefresh: () async {
              reload();
              try {
                await future;
              } catch (_) {}
            },
            child: ListView(padding: const EdgeInsets.all(12), children: [
              Text('${data['unread']} unread support alerts',
                  style: Theme.of(context).textTheme.titleMedium),
              if (items.isEmpty)
                const ListTile(title: Text('No support alerts yet')),
              for (final n in items)
                Card(
                    child: ListTile(
                        leading: Icon(n['read_at'] == null
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded),
                        title: Text('${n['title']}',
                            style: TextStyle(
                                fontWeight: n['read_at'] == null
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        subtitle: Text('${n['created_at']}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => open(n))),
            ]));
      });
}
