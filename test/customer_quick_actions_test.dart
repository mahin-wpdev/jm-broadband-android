import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/panel_workspace.dart';

Future<Map<String, dynamic>> section(String name) async => {
      'available': true,
      'role': 'customer',
      'profile': {'name': 'Test Customer', 'username': 'test'},
      'package': {
        'name': '30 Mbps',
        'state': 'active',
        'speed': '30 Mbps',
        'price_bdt': 500,
        'balance_bdt': 0,
        'days_remaining': 12,
        'expiration': '2026-10-10',
      },
      'network': {
        'pppoe_online': true,
        'connected_seconds': 4500,
        'connected_since': '2026-09-25 10:00:00',
        'onu_rx_dbm': -20.5,
        'onu_status': 'ONLINE',
      },
      'monthly_usage': {
        'available': true,
        'total_bytes': 3000000000,
        'download_bytes': 2000000000,
        'upload_bytes': 1000000000,
      },
      'traffic_peak': {'available': false, 'has_record': false},
      'summary': <String, dynamic>{},
      'items': <Map<String, dynamic>>[],
    };

PanelWorkspace workspace() => PanelWorkspace(
      role: 'customer',
      name: 'Test Customer',
      load: section,
      loadTickets: () async => {'available': true, 'items': []},
      ticketDetail: (_) async => {'ticket': {}, 'events': []},
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
      loadAdminProfile: (_) async => {},
      loadExpiry: (_) async => {'available': true, 'items': []},
      rechargePreview: (_, __) async => {'preview': {}},
      recharge: (_) async => {},
      loadTraffic: () async => {
        'available': true,
        'online': true,
        'download_bps': 0,
        'upload_bps': 0
      },
      trafficHistoryKey: 'quick-action-test',
      onLogout: () async {},
      onCheckForUpdates: () async => false,
    );

void main() {
  testWidgets('customer bottom navigation has no duplicate Live or Support',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home: workspace()));
    await tester.pumpAndSettle();
    final nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    expect(
        find.descendant(of: nav, matching: find.text('Home')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Account')),
        findsOneWidget);
    expect(
        find.descendant(of: nav, matching: find.text('More')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Live')), findsNothing);
    expect(
        find.descendant(of: nav, matching: find.text('Support')), findsNothing);
  });

  testWidgets('quick actions open real Live and Bills sections',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home: workspace()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Arivo ISP Billing · Live'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bills').last);
    await tester.pumpAndSettle();
    expect(find.text('Arivo ISP Billing · Bills'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Support').last);
    await tester.pumpAndSettle();
    expect(find.text('Arivo ISP Billing · Support'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alerts').last);
    await tester.pumpAndSettle();
    expect(find.text('Arivo ISP Billing · Alerts'), findsOneWidget);
  });

  testWidgets('customer dashboard shows RADIUS connected duration',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home: workspace()));
    await tester.pumpAndSettle();
    expect(find.text('Connected for'), findsOneWidget);
    expect(find.text('1h 15m'), findsOneWidget);
  });
}
