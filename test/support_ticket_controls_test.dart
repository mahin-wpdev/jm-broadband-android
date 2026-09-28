import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/support_tickets_page.dart';

void main() {
  testWidgets('superadmin can close an open ticket', (tester) async {
    Map<String, dynamic>? update;
    await tester.pumpWidget(MaterialApp(
      home: SupportTicketDetailsPage(
        ticketId: 7,
        role: 'superadmin',
        load: (_) async => {
          'ticket': {
            'id': 7,
            'subject': 'Fiber issue',
            'category': 'network',
            'status': 'open',
            'description': 'Test ticket'
          },
          'events': <Map<String, dynamic>>[]
        },
        update: (data) async {
          update = Map<String, dynamic>.from(data);
          return {'id': 7, 'status': 'closed'};
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Close ticket'), findsOneWidget);
    await tester.tap(find.text('Close ticket'));
    await tester.pump();
    expect(update?['ticket_id'], 7);
    expect(update?['action'], 'status');
    expect(update?['status'], 'closed');
  });
}
