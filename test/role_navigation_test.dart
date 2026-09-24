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
    expect(find.text('Arivo · Home'), findsOneWidget);
    for (final label in ['Live', 'Bills', 'ONU', 'Inbox', 'Account', 'Home']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      expect(find.text('Arivo · $label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('reseller page navigation', (tester) async {
    await showRole(tester, 'reseller');
    for (final label in ['Customers', 'Sales', 'ONU', 'Account', 'Overview']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      expect(find.text('Arivo · $label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('admin page navigation', (tester) async {
    await showRole(tester, 'admin');
    for (final label in [
      'Customers',
      'Resellers',
      'Sales',
      'More',
      'Overview'
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      expect(find.text('Arivo · $label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
