import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/panel_workspace.dart';

Future<void> showHome(WidgetTester tester, Map<String, dynamic> usage) async {
  tester.view.physicalSize = const Size(1440, 3088);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: PanelWorkspace(
      role: 'customer',
      name: 'Test customer',
      trafficHistoryKey: 'test-customer',
      load: (_) async => {
        'role': 'customer',
        'profile': {'name': 'Test customer'},
        'package': {'name': 'Test package'},
        'network': {'usage_download_bytes': null, 'usage_upload_bytes': null},
        'monthly_usage': usage,
      },
      loadTraffic: () async => {},
      onLogout: () async {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows monthly download, upload, and total in GB',
      (tester) async {
    await showHome(tester, {
      'available': true,
      'month': '2026-09',
      'download_bytes': 2500000000,
      'upload_bytes': 500000000,
      'total_bytes': 3000000000,
      'note': 'Recorded RADIUS counters',
    });
    expect(find.text('Monthly bandwidth usage (2026-09)'), findsOneWidget);
    expect(find.text('2.50 GB'), findsOneWidget);
    expect(find.text('0.50 GB'), findsOneWidget);
    expect(find.text('3.00 GB'), findsOneWidget);
  });

  testWidgets('does not invent monthly GB when accounting is missing',
      (tester) async {
    await showHome(tester, {
      'available': false,
      'note': 'No verified monthly accounting data',
    });
    expect(find.text('Monthly bandwidth usage'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('No verified monthly accounting data'), findsOneWidget);
    expect(find.text('0.00 GB'), findsNothing);
  });
}
