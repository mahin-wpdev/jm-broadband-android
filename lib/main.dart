import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_update.dart';
import 'panel_workspace.dart';
import 'push_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await PushNotifications.instance.initialize();
  } catch (_) {
    // Login remains usable if Play Services/Firebase is temporarily unavailable.
  }
  runApp(const JmApp());
}

// Android may restore encrypted preferences without their device-bound Keystore key.
// Treat that old local session as invalid rather than trapping the app on splash.
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
);

/// Keeps the path to the existing panel; does not guess arbitrary server paths.
/// API file is installed beside panel/init.php.
Uri normalizeServer(String input) {
  var value = input.trim();
  if (value.isEmpty) throw const FormatException('Enter a server address');
  if (!value.contains('://')) value = 'https://$value';
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException(
        'Use a valid HTTPS domain or IP and optional /panel path');
  }
  // This public IP accepts HTTPS from LTE on 8443; the existing 443 path
  // remains available when the user explicitly enters :443.
  final useJmMobilePort = uri.host == '27.147.201.165' &&
      uri.port == 443 &&
      !RegExp(r':443(?:/|$)').hasMatch(value);
  final effective = useJmMobilePort ? uri.replace(port: 8443) : uri;
  var path = effective.path.replaceAll(RegExp(r'/+$'), '');
  if (effective.host == '27.147.201.165' && path.isEmpty) path = '/panel';
  if (path.endsWith('/mobile-api.php')) return effective.replace(path: path);
  return effective.replace(path: '$path/mobile-api.php');
}

// An Android key-reset result is not a saved server address.
Uri? restoredServerUri(String? value) {
  if (value == null || value == 'Data has been reset') return null;
  return normalizeServer(value);
}

const _localCertBase64 = String.fromEnvironment('JM_LOCAL_CERT_B64');

http.Client createApiClient(Uri url) {
  final isLocalDebugServer = kDebugMode &&
      url.scheme == 'https' &&
      url.host == 'localhost' &&
      url.port == 8443 &&
      _localCertBase64.isNotEmpty;

  if (!isLocalDebugServer) {
    return http.Client();
  }

  final context = SecurityContext(withTrustedRoots: true);

  context.setTrustedCertificatesBytes(
    base64Decode(_localCertBase64),
  );

  return IOClient(HttpClient(context: context));
}

ThemeData jmPremiumTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF087F6B),
    surface: const Color(0xFFF7FAF9),
  );
  final rounded =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
        elevation: 0.6,
        margin: const EdgeInsets.only(bottom: 12),
        shape: rounded,
        clipBehavior: Clip.antiAlias),
    appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0.5,
        backgroundColor: scheme.surface),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .45),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.primary, width: 1.4))),
    navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 3,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)))),
  );
}

class MobileApi {
  Uri? endpoint;
  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? user;

  Future<void> restore() async {
    try {
      // Include the first read in the recovery boundary: Android backups can
      // restore ciphertext after the encryption key was destroyed on uninstall.
      final server = await _storage.read(key: 'server');
      // Do not mistake the plugin's recovery marker for the server URL.
      final restoredEndpoint = restoredServerUri(server);
      if (restoredEndpoint == null) return;
      endpoint = restoredEndpoint;
      final newTokenKey = 'refresh:${endpoint.toString()}';
      refreshToken = await _storage.read(key: newTokenKey);
      // Migrate the old :443 session to the LTE-safe :8443 entrypoint
      // without deleting the previous saved token or reinstalling the app.
      if (refreshToken == null &&
          server != null &&
          server != endpoint.toString()) {
        refreshToken = await _storage.read(key: 'refresh:$server');
        if (refreshToken != null) {
          await _storage.write(key: newTokenKey, value: refreshToken);
        }
      }
      if (refreshToken != null) await refresh();
      if (accessToken != null) await me();
    } catch (_) {
      // A stale or undecryptable local login must never block first-run UI.
      accessToken = null;
      refreshToken = null;
      user = null;
      endpoint = null;
    }
  }

  Future<Map<String, dynamic>> request(String action,
      {Map<String, dynamic>? body,
      bool authorized = true,
      Map<String, String>? query,
      bool retry = true}) async {
    if (endpoint == null) throw StateError('Server is not configured');
    final url =
        endpoint!.replace(queryParameters: {'action': action, ...?query});
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authorized && accessToken != null)
        'Authorization': 'Bearer $accessToken',
    };
    // Never follow redirects: credentials must not cross server origins.
    final client = createApiClient(url);
    late final http.Response result;
    try {
      final req = http.Request(body == null ? 'GET' : 'POST', url);
      req.followRedirects = false;
      req.headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed =
          await client.send(req).timeout(const Duration(seconds: 15));
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        throw StateError(
            'Server redirected the API request; verify its HTTPS panel URL');
      }
      result = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw StateError(
          'Server connection timed out. Check the HTTPS server connection.');
    } on SocketException {
      throw StateError(
          'Cannot reach the Mobile API over HTTPS. Check your network or VPN and the server URL.');
    } on HandshakeException {
      throw StateError(
          'HTTPS certificate verification failed. Check the server certificate.');
    } finally {
      client.close();
    }
    Map<String, dynamic> response;
    try {
      response = Map<String, dynamic>.from(jsonDecode(result.body) as Map);
    } catch (_) {
      throw StateError('Server did not return Mobile API JSON');
    }
    if (result.statusCode == 401 &&
        authorized &&
        retry &&
        refreshToken != null) {
      await refresh();
      return request(action,
          body: body, authorized: authorized, query: query, retry: false);
    }
    if (result.statusCode >= 400) {
      throw StateError(response['error']?.toString() ?? 'Server error');
    }
    return response;
  }

  Future<String> discover(String server) async {
    endpoint = normalizeServer(server);
    final data = await request('server-info', authorized: false);
    final info = Map<String, dynamic>.from(data['data'] as Map);
    if (info['api_version'] != '1.0' || info['authentication'] != 'unified') {
      throw StateError('Incompatible server API');
    }
    return info['company_name']?.toString() ?? endpoint!.host;
  }

  Future<void> login(String server, String username, String password) async {
    // A previous server's token must never be used after changing server URL.
    accessToken = null;
    refreshToken = null;
    user = null;
    await discover(server);
    final data = await request('login',
        authorized: false, body: {'username': username, 'password': password});
    final payload = Map<String, dynamic>.from(data['data'] as Map);
    accessToken = payload['access_token'] as String;
    refreshToken = payload['refresh_token'] as String;
    user = Map<String, dynamic>.from(payload['user'] as Map);
    await _storage.write(key: 'server', value: endpoint.toString());
    await _storage.write(
        key: 'refresh:${endpoint.toString()}', value: refreshToken);
  }

  Future<void> refresh() async {
    if (refreshToken == null) throw StateError('Please log in');
    final data = await request('refresh',
        authorized: false, body: {'refresh_token': refreshToken});
    final payload = Map<String, dynamic>.from(data['data'] as Map);
    accessToken = payload['access_token'] as String;
    refreshToken = payload['refresh_token'] as String;
    await _storage.write(
        key: 'refresh:${endpoint.toString()}', value: refreshToken);
  }

  Future<void> me() async {
    final data = await request('me');
    user = Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<void> logout() async {
    try {
      if (accessToken != null) await request('logout', body: {});
    } catch (_) {
      // Remove the local session even when server is unreachable.
    } finally {
      if (endpoint != null) {
        await _storage.delete(key: 'refresh:${endpoint.toString()}');
      }
      accessToken = null;
      refreshToken = null;
      user = null;
    }
  }
}

class JmApp extends StatefulWidget {
  final MobileApi? initialApi;
  const JmApp({super.key, this.initialApi});
  @override
  State<JmApp> createState() => _JmAppState();
}

class _JmAppState extends State<JmApp> with WidgetsBindingObserver {
  late final MobileApi api = widget.initialApi ?? MobileApi();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<RemoteMessage>? pushMessageSub;
  bool loading = true;
  bool checkingUpdate = false;
  AppRelease? updateRelease;
  static final Uri _defaultUpdateEndpoint =
      normalizeServer('https://27.147.201.165/panel');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pushMessageSub =
        PushNotifications.instance.foregroundMessages.listen((message) {
      final title = message.notification?.title ?? 'Arivo ISP Billing';
      final body = message.notification?.body ?? 'New notification';
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('$title\n$body')),
      );
    });
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pushMessageSub?.cancel();
    PushNotifications.instance.unbindTokenSink();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !loading &&
        updateRelease == null) {
      _checkForUpdate();
    }
  }

  Future<bool> _checkForUpdate({Uri? endpoint, bool manual = false}) async {
    if (checkingUpdate) return updateRelease != null;
    checkingUpdate = true;
    try {
      final release = await AppUpdater.check(
          endpoint ?? api.endpoint ?? _defaultUpdateEndpoint);
      if (mounted) setState(() => updateRelease = release);
      return release != null;
    } catch (_) {
      if (manual) rethrow;
      return false;
    } finally {
      checkingUpdate = false;
    }
  }

  Future<void> _registerPushToken(String token) async {
    if (api.user == null || api.accessToken == null || token.isEmpty) return;
    try {
      final meta = await PushNotifications.instance.deviceMetadata();
      await api.request('push-register', body: {'token': token, ...meta});
    } catch (_) {
      // Push registration must never block login or normal ISP operations.
    }
  }

  Future<void> _syncPush() async {
    if (api.user == null || api.accessToken == null) return;
    try {
      await PushNotifications.instance.initialize();
      await PushNotifications.instance.bindTokenSink(_registerPushToken);
    } catch (_) {
      // Play Services or Firebase can be unavailable temporarily.
    }
  }

  Future<void> _boot() async {
    try {
      await api.restore().timeout(const Duration(seconds: 25));
    } catch (_) {
      // Storage/plugin errors or hung restoration must show the Login screen.
      api.accessToken = null;
      api.refreshToken = null;
      api.user = null;
      api.endpoint = null;
    }
    if (!mounted) return;
    // A broken mobile-data route to the update endpoint must never hold
    // the splash screen hostage while the user needs the sign-in UI.
    setState(() => loading = false);
    if (api.user != null) unawaited(_syncPush());
    unawaited(
        _checkForUpdate(endpoint: api.endpoint ?? _defaultUpdateEndpoint));
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Arivo ISP Billing',
        scaffoldMessengerKey: messengerKey,
        debugShowCheckedModeBanner: false,
        theme: jmPremiumTheme(),
        home: loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : updateRelease != null
                ? AppUpdatePage(
                    release: updateRelease!,
                    onLater: updateRelease!.required
                        ? null
                        : () => setState(() => updateRelease = null))
                : api.user == null
                    ? LoginScreen(
                        api: api,
                        onLogin: () async {
                          await _syncPush();
                          await _checkForUpdate(endpoint: api.endpoint);
                          if (mounted) setState(() {});
                        })
                    : RoleDashboard(
                        api: api,
                        onLogout: () => setState(() {}),
                        onCheckForUpdates: () => _checkForUpdate(
                            endpoint: api.endpoint, manual: true)),
      );
}

class LoginScreen extends StatefulWidget {
  final MobileApi api;
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.api, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final server = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final endpoint = widget.api.endpoint;
    server.text = endpoint?.host == '27.147.201.165'
        ? 'https://27.147.201.165/panel/'
        : endpoint?.toString().replaceAll('/mobile-api.php', '') ??
            'https://27.147.201.165/panel/';
  }

  @override
  void dispose() {
    server.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.login(server.text, username.text.trim(), password.text);
      if (mounted) widget.onLogin();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset('assets/branding/logo.png',
                              height: 100, fit: BoxFit.contain),
                          const SizedBox(height: 15),
                          const Text('Arivo ISP Billing',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.bold)),
                          const Text('Customer • Reseller • Admin',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 35),
                          TextField(
                              controller: server,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                  labelText: 'Server IP / Domain',
                                  hintText: 'https://isp.example.com/panel',
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 15),
                          TextField(
                              controller: username,
                              decoration: const InputDecoration(
                                  labelText: 'Username',
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 15),
                          TextField(
                              controller: password,
                              obscureText: true,
                              onSubmitted: (_) => submit(),
                              decoration: const InputDecoration(
                                  labelText: 'Password',
                                  border: OutlineInputBorder())),
                          if (error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Text(error!,
                                    style: const TextStyle(color: Colors.red))),
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: busy ? null : submit,
                              child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child:
                                      Text(busy ? 'Connecting…' : 'Sign In'))),
                          const SizedBox(height: 16),
                          const Text(
                              'HTTPS required. Your username and password are sent only to the selected server.',
                              textAlign: TextAlign.center),
                        ])))),
      );
}

class RoleDashboard extends StatelessWidget {
  final MobileApi api;
  final VoidCallback onLogout;
  final Future<bool> Function() onCheckForUpdates;
  const RoleDashboard(
      {super.key,
      required this.api,
      required this.onLogout,
      required this.onCheckForUpdates});
  @override
  Widget build(BuildContext context) {
    final user = api.user ?? {};
    final role = user['role']?.toString() ?? 'unknown';
    return PanelWorkspace(
      role: role,
      name: (user['name'] ?? user['username'] ?? '').toString(),
      load: (section) async {
        final response =
            await api.request('mobile-data', query: {'section': section});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      searchCustomers: (query) async {
        final response = await api.request('mobile-data',
            query: {'section': 'customers', 'q': query});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      loadAdminOnus: (query, filter) async {
        final response = await api
            .request('admin-onu-list', query: {'q': query, 'filter': filter});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      assignOnu: (input) async {
        final response = await api.request('admin-onu-assign', body: input);
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      unassignOnu: (input) async {
        final response = await api.request('admin-onu-unassign', body: input);
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      removeOnu: (input) async {
        final response = await api.request('admin-onu-remove', body: input);
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      loadTickets: () async {
        final response = await api.request('ticket-list');
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      ticketDetail: (ticketId) async {
        final response = await api
            .request('ticket-detail', query: {'ticket_id': '$ticketId'});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      createTicket: (data) async {
        final response = await api.request('ticket-create', body: data);
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      updateTicket: (data) async {
        final response = await api.request('ticket-update', body: data);
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      ticketNotifications: () async {
        final response = await api.request('ticket-notifications');
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      readTicketNotification: (id) async {
        final response = await api
            .request('ticket-notification-read', body: {'notification_id': id});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      searchRecharge: (query) async {
        final response =
            await api.request('admin-recharge-search', query: {'q': query});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      rechargeOptions: (customerId) async {
        final response = await api.request('admin-recharge-options',
            query: {'customer_id': '$customerId'});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      loadAdminProfile: (customerId) async {
        final response = await api.request('admin-customer-profile',
            query: {'customer_id': '$customerId'});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      loadExpiry: (window) async {
        final response =
            await api.request('admin-expiry', query: {'window': window});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      rechargePreview: (customerId, planId) async {
        final response = await api.request('admin-recharge-preview',
            query: {'customer_id': '$customerId', 'plan_id': '$planId'});
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      recharge: (request) async {
        final response = await api.request('admin-recharge', body: request);
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      loadTraffic: () async {
        final response = await api.request('live-traffic');
        return Map<String, dynamic>.from(response['data'] as Map);
      },
      trafficHistoryKey: 'arivo:traffic:${api.endpoint}:${user['role']}:'
          '${user['id'] ?? user['username']}',
      onCheckForUpdates: onCheckForUpdates,
      onLogout: () async {
        try {
          final token = await PushNotifications.instance.currentToken();
          if (token != null && api.accessToken != null) {
            await api.request('push-unregister', body: {'token': token});
          }
        } catch (_) {
          // Server logout still proceeds when push cleanup is unavailable.
        }
        await PushNotifications.instance.unbindTokenSink();
        await api.logout();
        onLogout();
      },
    );
  }
}
