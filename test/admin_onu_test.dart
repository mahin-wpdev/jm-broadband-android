import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/admin_onu_page.dart';

void main() {
  testWidgets('unassigned online ONU can assign but cannot remove from OLT',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminOnuPage(
          load: (_, __) async => {
            'available': true,
            'items': [
              {
                'id': 1,
                'status': 'ONLINE',
                'mac_address': 'AA:BB:CC:DD:EE:FF',
                'pon_port': '1',
                'onu_id': '9',
                'olt_name': 'OLT 1',
                'assigned': false,
                'can_remove_from_olt': false,
                'rx_power': '-20.1',
              }
            ]
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
    expect(find.text('Unassign'), findsNothing);
    expect(find.text('Remove from OLT'), findsNothing);
  });

  testWidgets('offline unassigned ONU exposes guarded OLT removal',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminOnuPage(
          load: (_, __) async => {
            'available': true,
            'items': [
              {
                'id': 2,
                'status': 'OFFLINE',
                'mac_address': '11:22:33:44:55:66',
                'pon_port': '2',
                'onu_id': '3',
                'olt_name': 'OLT 1',
                'assigned': false,
                'can_remove_from_olt': true,
              }
            ]
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
    expect(find.text('Remove from OLT'), findsOneWidget);
  });
}
