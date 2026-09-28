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
      load: (section) async {
        final data = await fakeSection(section);
        data['role'] = role;
        data['summary'] = <String, dynamic>{
          'customers': 12,
          'active_customers': 9,
          'monthly_recorded_sales_bdt': 6400,
          'inactive_customers': 3,
          'profile_profit_percentage': 20,
          'expiring_7_days': 2,
          'profit_payable_bdt': 900,
          'profit_today_bdt': 50,
          'profit_month_bdt': 600,
          'profit_lifetime_bdt': 2400,
          'total_settled_bdt': 1500,
          'allowed_packages': 2,
          'onu_total': 4,
          'onu_online': 3,
          'onu_offline': 1,
          'service_active_total': 9,
          'service_inactive_total': 3,
          'reseller_total': 3,
          'reseller_active_total': 2,
          'reseller_customer_total': 7,
          'reseller_pending_customers': 1,
          'reseller_profit_due_bdt': 1200,
          'reseller_month_profit_bdt': 400,
          'reseller_month_sales_bdt': 4200,
          'onu_online_total': 8,
          'onu_offline_total': 2,
          'onu_los_total': 1,
          'onu_unassigned_total': 3,
          'olt_online_total': 1,
          'olt_total': 1,
          'olt_last_sync_status': 'success',
          'olt_last_sync_at': '2026-09-28 00:30:00',
        };
        if (role == 'reseller') {
          data['recent_earnings'] = [
            {
              'fullname': 'Customer One',
              'username': 'one',
              'plan_name': '40 Mbps',
              'created_at': '2026-09-28 00:10:00',
              'recharge_amount': 500,
              'profit_amount': 50
            }
          ];
          data['settlements'] = [
            {
              'created_at': '2026-09-27',
              'amount': 100,
              'payment_method': 'Cash',
              'reference': 'SET-1'
            }
          ];
          data['allowed_packages'] = [
            {
              'name_plan': '40 Mbps',
              'type': 'PPPOE',
              'price': 500,
              'validity': 30,
              'validity_unit': 'Days'
            }
          ];
        } else if (role == 'admin') {
          data['reseller_overview'] = [
            {
              'name': 'Reseller One',
              'status': 'active',
              'profit_percentage': 20,
              'customer_count': 7,
              'active_count': 6,
              'month_sales': 4200,
              'profit_due': 800
            }
          ];
        }
        return data;
      },
      loadTickets: () async => {'available': true, 'items': []},
      ticketDetail: (_) async => {
        'ticket': {'subject': 'Test', 'status': 'open'},
        'events': []
      },
      createTicket: (_) async => {'id': 1},
      updateTicket: (_) async => {'id': 1},
      ticketNotifications: () async => {'unread': 0, 'items': []},
      readTicketNotification: (_, __) async => {'ok': true},
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
      if (!['Home', 'Inbox', 'Account'].contains(label)) {
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
    expect(find.text('Reseller dashboard'), findsOneWidget);
    expect(find.text('Customer monitoring'), findsOneWidget);
    expect(find.text('This month sales'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Recent earnings'), 500,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Profit payable'), findsOneWidget);
    expect(find.text('Recent earnings'), findsOneWidget);
    expect(find.text('Settlement history'), findsOneWidget);
    expect(find.text('Allowed packages'), findsWidgets);
    for (final label in ['Customers', 'Sales', 'ONU', 'Account', 'Dashboard']) {
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
    expect(find.text('Admin dashboard'), findsOneWidget);
    expect(find.text('Customer monitoring'), findsOneWidget);
    expect(find.text('This month sales'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Reseller management'), 500,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Reseller overview'), findsOneWidget);
    expect(find.text('Network & OLT'), findsOneWidget);
    expect(find.text('Reseller management'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    for (final label in [
      'Customers',
      'Inbox',
      'Recharge',
      'Support',
      'Resellers',
      'Sales',
      'Expiry',
      'Dashboard'
    ]) {
      if (['Support', 'Resellers', 'Sales', 'Expiry'].contains(label)) {
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
