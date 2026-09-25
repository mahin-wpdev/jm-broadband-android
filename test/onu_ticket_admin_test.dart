import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/admin_onu_page.dart';
import 'package:jm_broadband_app/support_tickets_page.dart';

void main() {
  testWidgets('superadmin sees explicit close ticket action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SupportTicketDetailsPage(
        ticketId: 7,
        role: 'superadmin',
        load: (_) async => {
          'ticket': {
            'id': 7,
            'subject': 'No internet',
            'category': 'no_internet',
            'description': 'Test',
            'status': 'in_progress',
          },
          'events': <Map<String, dynamic>>[],
        },
        update: (_) async => {'id': 7, 'status': 'closed'},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Close ticket'), findsOneWidget);
    expect(find.text('Ticket status'), findsOneWidget);
  });

  testWidgets('ONU manager exposes assign and unassign safely', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminOnuPage(
          load: (_, __) async => {
            'available': true,
            'items': [
              {
                'id': 10,
                'olt_id': 1,
                'olt_name': 'OLT 1',
                'status': 'ONLINE',
                'mac_address': 'AA:BB:CC:DD:EE:01',
                'pon_port': '2',
                'onu_id': '5',
                'rx_power': '-21.4',
                'assigned': false,
                'can_remove_from_olt': false,
              },
              {
                'id': 11,
                'olt_id': 1,
                'olt_name': 'OLT 1',
                'status': 'ONLINE',
                'mac_address': 'AA:BB:CC:DD:EE:02',
                'pon_port': '3',
                'onu_id': '6',
                'rx_power': '-20.2',
                'assigned': true,
                'customer_id': 22,
                'customer_username': 'jmbroadband',
                'customer_name': 'JM Broadband',
                'can_remove_from_olt': false,
              }
            ],
            'note': 'Test inventory'
          },
          searchCustomers: (_) async => {'available': true, 'items': []},
          assign: (_) async => {'assigned': true},
          unassign: (_) async => {'unassigned': true},
          remove: (_) async => {'removed': true},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Assign'), findsOneWidget);
    expect(find.text('Unassign'), findsOneWidget);
    expect(find.text('Remove from OLT'), findsNothing);
    expect(find.textContaining('jmbroadband'), findsOneWidget);
  });
}
