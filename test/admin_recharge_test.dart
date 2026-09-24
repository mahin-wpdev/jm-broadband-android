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
      load: (_) async => {'available': true, 'role': role, 'items': []},
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
