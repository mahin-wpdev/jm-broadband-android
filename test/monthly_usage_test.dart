import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/panel_workspace.dart';

Future<void> showHome(WidgetTester tester, Map<String, dynamic> usage,
    {Map<String, dynamic>? trafficPeak}) async {
  tester.view.physicalSize = const Size(1440, 6000);
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
        'package': {
          'name': 'Test package',
          'state': 'active',
          'speed': '30 Mbps',
          'price_bdt': 500,
          'balance_bdt': 0,
          'expiration': '2026-10-15',
          'days_remaining': 20,
        },
        'network': {
          'usage_download_bytes': null,
          'usage_upload_bytes': null,
          'onu_rx_dbm': -21.3,
          'onu_status': 'ONLINE',
        },
        'monthly_usage': usage,
        'traffic_peak': trafficPeak,
      },
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
      loadTraffic: () async => {},
      onLogout: () async {},
      onCheckForUpdates: () async => false,
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
    expect(find.text('3.00 GB'), findsWidgets);
  });

  testWidgets('does not invent monthly GB when accounting is missing',
      (tester) async {
    await showHome(tester, {
      'available': false,
      'note': 'No verified monthly accounting data',
    });
    expect(find.text('Monthly bandwidth usage'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('No verified monthly accounting data'), findsOneWidget);
    expect(find.text('0.00 GB'), findsNothing);
  });

  testWidgets('Home shows server-recorded peak without phone history',
      (tester) async {
    await showHome(tester, {
      'available': false
    }, trafficPeak: {
      'source': 'radius_accounting',
      'available': true,
      'has_record': true,
      'download_bps': 32000000,
      'upload_bps': 8000000,
      'download_at_ms': 1790000000000,
      'upload_at_ms': 1790000001000,
    });
    expect(find.text('Server-recorded highest speed'), findsOneWidget);
    expect(find.text('32.00 Mbps'), findsOneWidget);
    expect(find.text('8.00 Mbps'), findsOneWidget);
    expect(find.text('No record'), findsNothing);
  });

  testWidgets('customer dashboard is icon-first and understandable at a glance',
      (tester) async {
    await showHome(tester, {
      'available': true,
      'month': '2026-09',
      'download_bytes': 2000000000,
      'upload_bytes': 1000000000,
      'total_bytes': 3000000000,
    });
    expect(find.text('Internet service active'), findsOneWidget);
    expect(find.text('Package'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Days left'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('ONU signal'), findsOneWidget);
    expect(find.text('Account balance'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    for (final action in ['Live', 'Bills', 'Support', 'Alerts']) {
      expect(find.text(action), findsWidgets);
    }
    expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
    expect(find.byIcon(Icons.support_agent_rounded), findsWidgets);
  });
}
