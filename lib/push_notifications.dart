import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';

@pragma('vm:entry-point')
Future<void> jmFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotifications {
  PushNotifications._();
  static final instance = PushNotifications._();

  final _foreground = StreamController<RemoteMessage>.broadcast();
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenSub;
  bool _initialized = false;
  Future<void> Function(String token)? _tokenSink;

  Stream<RemoteMessage> get foregroundMessages => _foreground.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(jmFirebaseBackgroundHandler);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _messageSub = FirebaseMessaging.onMessage.listen(_foreground.add);
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final sink = _tokenSink;
      if (sink != null) unawaited(sink(token));
    });
    _initialized = true;
  }

  Future<String?> currentToken() async {
    if (!_initialized) await initialize();
    return FirebaseMessaging.instance.getToken();
  }

  Future<Map<String, String>> deviceMetadata() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'app_version': '${info.version}+${info.buildNumber}',
      'device_label': Platform.operatingSystem,
    };
  }

  Future<void> bindTokenSink(Future<void> Function(String token) sink) async {
    _tokenSink = sink;
    final token = await currentToken();
    if (token != null && token.isNotEmpty) await sink(token);
  }

  Future<void> unbindTokenSink() async {
    _tokenSink = null;
  }

  Future<void> deleteLocalToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Logout must still complete if Play Services is temporarily unavailable.
    }
  }

  Future<RemoteMessage?> initialMessage() async {
    if (!_initialized) await initialize();
    return FirebaseMessaging.instance.getInitialMessage();
  }

  Future<void> dispose() async {
    await _messageSub?.cancel();
    await _tokenSub?.cancel();
    await _foreground.close();
  }
}
