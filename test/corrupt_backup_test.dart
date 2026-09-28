import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jm_broadband_app/main.dart';

class _BadBackupApi extends MobileApi {
  @override
  Future<void> restore() async {
    throw PlatformException(code: 'BAD_DECRYPT');
  }
}

void main() {
  testWidgets('corrupt restored login never traps app on splash',
      (tester) async {
    await tester.pumpWidget(JmApp(initialApi: _BadBackupApi()));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Server IP / Domain'), findsOneWidget);
  });
}
