import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/support_tickets_page.dart';

void main() {
  testWidgets(
      'panel message appears in Alerts and marks read without opening a ticket',
      (tester) async {
    int? markedId;
    String? markedType;
    int openedTickets = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TicketNotificationsPage(
          load: () async => {
            'available': true,
            'unread': 1,
            'items': [
              {
                'id': 42,
                'ticket_id': null,
                'kind': 'panel_message',
                'title': 'Maintenance notice',
                'body': 'Internet maintenance tonight at 2 AM.',
                'created_at': '2026-09-25 18:00:00',
                'read_at': null,
              }
            ],
          },
          markRead: (id, type) async {
            markedId = id;
            markedType = type;
            return {'ok': true};
          },
          onTicket: (_) => openedTickets++,
        ),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.text('1 unread alerts'), findsOneWidget);
    expect(find.text('Maintenance notice'), findsOneWidget);
    expect(find.textContaining('Internet maintenance tonight'), findsOneWidget);
    expect(find.byIcon(Icons.campaign_rounded), findsOneWidget);

    await tester.tap(find.text('Maintenance notice'));
    await tester.pumpAndSettle();
    expect(markedId, 42);
    expect(markedType, 'panel_message');
    expect(openedTickets, 0);
  });
}
