import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/panel_workspace.dart';

Future<Map<String, dynamic>> fakeSection(String section) async => {
      'available': true,
      'role': 'customer',
      'profile': <String, dynamic>{'name': 'Test Customer'},
      'package': <String, dynamic>{},
      'network': <String, dynamic>{},
      'monthly_usage': <String, dynamic>{'available': false},
      'summary': <String, dynamic>{},
      'items': <Map<String, dynamic>>[],
    };

Future<Map<String, dynamic>> fakeTraffic() async => {
      'available': false,
      'online': false,
    };

Future<void> showRole(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(1440, 3120);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
    home: PanelWorkspace(
      role: role,
      name: 'Test User',
      load: fakeSection,
      loadTickets: () async => {'available': true, 'items': []},
      ticketDetail: (_) async => {
        'ticket': {'subject': 'Test', 'status': 'open'},
        'events': []
      },
      createTicket: (_) async => {'id': 1},
      updateTicket: (_) async => {'id': 1},
      ticketNotifications: () async => {'unread': 0, 'items': []},
      readTicketNotification: (_) async => {'ok': true},
      searchCustomers: (_) async => {'available': true, 'items': []},
      loadAdminOnus: (_, __) async => {'available': true, 'items': []},
      assignOnu: (_) async => {'assigned': true},
      unassignOnu: (_) async => {'unassigned': true},
      removeOnu: (_) async => {'removed': true},
      searchRecharge: (_) async => {'available': true, 'items': []},
      rechargeOptions: (_) async => {'customer': {}, 'items': []},
      loadAdminProfile: (_) async => {
        'customer': {
          'username': 'test-user',
          'fullname': 'Test User',
          'status': 'Active'
        },
        'monthly_usage': {},
        'transactions': [],
        'admin_recharge_requests': []
      },
      loadExpiry: (_) async => {'available': true, 'count': 0, 'items': []},
      rechargePreview: (_, __) async => {
        'preview': {
          'package_price_bdt': '500.00',
          'additional_bills_bdt': '0.00',
          'expected_recorded_amount_bdt': '500.00',
          'period_invoice_override_bdt': null,
          'note': 'Test preview'
        }
      },
      recharge: (_) async => {'invoice': 'INV-TEST'},
      loadTraffic: fakeTraffic,
      trafficHistoryKey: 'widget-test-$role',
      onLogout: () async {},
      onCheckForUpdates: () async => false,
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('customer Home Live Bills ONU Inbox Account navigation',
      (tester) async {
    await showRole(tester, 'customer');
    expect(find.text('Arivo ISP Billing · Home'), findsOneWidget);
    for (final label in [
      'Live',
      'Support',
      'Bills',
      'ONU',
      'Inbox',
      'Account',
      'Home'
    ]) {
      if (!['Home', 'Live', 'Support', 'Account'].contains(label)) {
        await tester.tap(find.text('More').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.text('Arivo ISP Billing · $label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('reseller page navigation', (tester) async {
    await showRole(tester, 'reseller');
    for (final label in ['Customers', 'Sales', 'ONU', 'Account', 'Overview']) {
      if (label == 'ONU') {
        await tester.tap(find.text('More').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.text('Arivo ISP Billing · $label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('admin page navigation', (tester) async {
    await showRole(tester, 'admin');
    for (final label in [
      'Customers',
      'Recharge',
      'Support',
      'Resellers',
      'Sales',
      'Expiry',
      'Overview'
    ]) {
      if (['Resellers', 'Sales', 'Expiry'].contains(label)) {
        await tester.tap(find.text('More').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.text('Arivo ISP Billing · $label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
