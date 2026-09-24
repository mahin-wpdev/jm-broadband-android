import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/panel_workspace.dart';

Future<void> showRechargeRole(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(1440, 3120);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: PanelWorkspace(
      role: role,
      name: 'Test user',
      load: (section) async => {
        'available': true,
        'role': role,
        'items': section == 'customers'
            ? [
                {
                  'id': 1,
                  'username': 'test-user',
                  'fullname': 'Test User',
                  'status': 'Active'
                }
              ]
            : []
      },
      loadTraffic: () async => {},
      searchRecharge: (_) async => {
        'available': true,
        'items': [
          {
            'id': 1,
            'username': 'test-user',
            'fullname': 'Test User',
            'can_recharge': true,
            'name_plan': '30 Mbps',
            'routers': 'Router One',
            'price': '500.00'
          },
        ]
      },
      rechargeOptions: (_) async => {
        'available': true,
        'customer': {
          'id': 1,
          'username': 'test-user',
          'fullname': 'Test User',
          'plan_id': 3,
          'name_plan': '30 Mbps',
          'price': '500.00',
          'routers': 'Router One',
          'status': 'Active'
        },
        'items': [
          {'id': 3, 'name_plan': '30 Mbps', 'price': '500.00'},
          {'id': 4, 'name_plan': '40 Mbps', 'price': '700.00'},
        ]
      },
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
      recharge: (_) async => {'invoice': 'INV-TEST-1'},
      trafficHistoryKey: 'test-$role',
      onLogout: () async {},
      onCheckForUpdates: () async => false,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recharge tab never appears for customers or resellers',
      (tester) async {
    await showRechargeRole(tester, 'customer');
    expect(find.text('Recharge'), findsNothing);
    await showRechargeRole(tester, 'reseller');
    expect(find.text('Recharge'), findsNothing);
  });

  testWidgets('expiry dashboard and profile are admin-only', (tester) async {
    await showRechargeRole(tester, 'customer');
    expect(find.text('Expiry'), findsNothing);
    await showRechargeRole(tester, 'reseller');
    expect(find.text('Expiry'), findsNothing);
    await showRechargeRole(tester, 'admin');
    await tester.tap(find.text('Expiry').last);
    await tester.pumpAndSettle();
    expect(find.text('Expiry period'), findsOneWidget);
    expect(find.text('Customers: 0'), findsOneWidget);
    await tester.tap(find.text('Customers').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile / history').first);
    await tester.pumpAndSettle();
    expect(find.text('Customer profile'), findsOneWidget);
    expect(find.text('Recorded transaction history'), findsOneWidget);
    expect(find.text('Recharge / change package'), findsOneWidget);
  });

  testWidgets('admin customer card has its own recharge button',
      (tester) async {
    await showRechargeRole(tester, 'admin');
    await tester.tap(find.text('Customers').last);
    await tester.pumpAndSettle();
    expect(find.text('Recharge'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Recharge').first);
    await tester.pumpAndSettle();
    expect(find.text('Admin manual recharge'), findsOneWidget);
    expect(find.text('Review & recharge'), findsOneWidget);
  });

  testWidgets('admin can search and select any named customer', (tester) async {
    await showRechargeRole(tester, 'admin');
    await tester.tap(find.text('Recharge').last);
    await tester.pumpAndSettle();
    expect(find.text('Admin manual recharge'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'test-user');
    await tester.tap(find.text('Search customers'));
    await tester.pumpAndSettle();
    expect(find.textContaining('test-user'), findsWidgets);
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    expect(find.text('Review & recharge'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('40 Mbps · ৳700.00').last);
    await tester.pumpAndSettle();
    expect(find.text('40 Mbps · ৳700.00'), findsOneWidget);
    await tester.tap(find.text('Review & recharge'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Recharge now');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'wrong-user');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'test-user');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
  });
}
