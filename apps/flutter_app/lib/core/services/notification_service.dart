import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NotificationCategory {
  gameInvite,
  turnReminder,
  friendRequest,
  challengeReady,
  seasonReward,
  dailyBonus,
  chatMessage,
  tournamentStart,
  systemAlert,
}

/// Push + local notifications.
///
/// Server-sent pushes originate from the `notify-dispatch` edge function
/// (fed by pg_net triggers — see migration 20260707000000_push_backbone.sql)
/// and carry a `route` in their data payload; tapping one navigates there.
///
/// Firebase init can legitimately fail (iOS until GoogleService-Info.plist +
/// the push entitlement land, or any platform without config). Every public
/// method no-ops in that state so the rest of the app never has to care.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const _channelId = 'gathr_default';

  final _local = FlutterLocalNotificationsPlugin();
  bool _firebaseAvailable = false;
  bool _localAvailable = false;
  String? _pendingRoute;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _tokenSub;

  /// Set by the router once it exists; taps that arrive earlier (cold start
  /// from a notification) are parked in [_pendingRoute] until then.
  void Function(String route)? _onTapRoute;
  set onTapRoute(void Function(String route) handler) {
    _onTapRoute = handler;
    final pending = _pendingRoute;
    if (pending != null) {
      _pendingRoute = null;
      handler(pending);
    }
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested in context via requestPermissionIfNeeded,
          // not at startup.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _handleTap(response.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Gathr notifications',
            description: 'Messages, invites and game updates',
            importance: Importance.high,
          ));
      _localAvailable = true;
    } catch (e) {
      debugPrint('Local notifications unavailable: $e');
    }

    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
    } catch (e) {
      debugPrint('Firebase init skipped (no platform config yet?): $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Token registration is the load-bearing part — attach it FIRST. Some
    // firebase_messaging platform futures (getInitialMessage in particular)
    // can hang forever on iOS; nothing below may gate this.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.initialSession) {
        unawaited(_registerToken());
        unawaited(_syncTimezoneOffset());
      }
    });
    _tokenSub = messaging.onTokenRefresh.listen((_) => _registerToken());

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _handleTap(message.data['route'] as String?));

    // iOS presents foreground notifications natively; on Android FCM does
    // not, so _onForegroundMessage mirrors them through the local plugin.
    unawaited(messaging
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        )
        .catchError((Object e) =>
            debugPrint('Foreground presentation options failed: $e')));

    // Cold start from a notification tap: resolve in the background — this
    // future is the one with the documented iOS hang.
    unawaited(messaging.getInitialMessage().then((initial) {
      if (initial != null) {
        _handleTap(initial.data['route'] as String?);
      }
    }).catchError((Object e) {
      debugPrint('getInitialMessage failed: $e');
    }));
  }

  /// Ask for notification permission. Call from a moment where the user just
  /// did something social (opened Messages, sent an invite) — not at launch.
  Future<bool> requestPermissionIfNeeded() async {
    if (!_firebaseAvailable) return false;
    try {
      final current =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (current.authorizationStatus == AuthorizationStatus.authorized) {
        // Already granted (possibly by a previous install of the same bundle
        // id) — this call is then the only reliable moment to (re)register.
        await _registerToken();
        return true;
      }
      if (current.authorizationStatus == AuthorizationStatus.denied) {
        // Previously refused; don't nag — the OS settings screen is the only
        // way back in.
        return false;
      }
      final settings = await FirebaseMessaging.instance.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        await _registerToken();
      }
      return granted;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  /// Remove this device's token row. Must run BEFORE auth.signOut() — RLS
  /// blocks the delete once the session is gone.
  Future<void> unregisterCurrentToken() async {
    if (!_firebaseAvailable) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await client
          .from('device_push_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
    } catch (e) {
      debugPrint('Push token unregister failed: $e');
    }
  }

  /// Show a locally-generated notification (in-app events that deserve a
  /// system banner, e.g. "back to the game — it's your turn").
  Future<void> show({
    required NotificationCategory category,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (!_localAvailable) return;
    await _local.show(
      Object.hash(category, title, body),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Gathr notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: data?['route'] as String?,
    );
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || !Platform.isAndroid || !_localAvailable) {
      return;
    }
    await _local.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Gathr notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['route'] as String?,
    );
  }

  // Routes we accept from a (server-controlled) push payload. Validated against
  // an allow-list so that anyone who ever gains FCM send capability can't drive
  // users to arbitrary in-app screens. See SECURITY-AUDIT L11 / GUIDELINES C5.
  static const _allowedRoutePrefixes = <String>[
    '/room/',
    '/messages', // DM inbox + /messages/:userId threads
    '/tournaments',
    '/tournament/', // detail: /tournament/:id
    '/friends',
    '/challenges',
    '/notifications',
    '/shop',
  ];

  static bool _isAllowedRoute(String route) {
    // Must be an internal absolute path (no scheme/host), and match an allowed
    // prefix — blocks '//evil.com', 'https://…', and unknown deep targets.
    if (!route.startsWith('/') || route.startsWith('//')) return false;
    return _allowedRoutePrefixes.any(
      (p) => route == p || route.startsWith(p),
    );
  }

  void _handleTap(String? route) {
    if (route == null || route.isEmpty) return;
    if (!_isAllowedRoute(route)) {
      debugPrint('Ignoring push route not on allow-list: $route');
      return;
    }
    final handler = _onTapRoute;
    if (handler != null) {
      handler(route);
    } else {
      _pendingRoute = route;
    }
  }

  Future<void> _registerToken() async {
    if (!_firebaseAvailable) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final token = await _getTokenWaitingForApns();
      if (token == null) return;
      await client.from('device_push_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }

  /// On iOS the FCM token can't be minted until Apple delivers the APNs
  /// token, which races app startup — getToken() then throws
  /// [firebase_messaging/apns-token-not-set]. Poll briefly instead of
  /// dropping the registration on the floor.
  Future<String?> _getTokenWaitingForApns() async {
    final messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) {
      // The iOS plugin only calls registerForRemoteNotifications from within
      // requestPermission() — without this, the APNs token never arrives for
      // users whose permission was granted by a previous install. It shows no
      // prompt once the status is already determined, so only skip it when a
      // prompt could actually appear (notDetermined).
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.notDetermined &&
          settings.authorizationStatus != AuthorizationStatus.denied) {
        await messaging.requestPermission();
      }
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    try {
      return await messaging.getToken();
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') return null;
      rethrow;
    }
  }

  /// Server-side quiet hours are evaluated against the device's UTC offset
  /// (see _shared/push.ts). Refreshed on every sign-in, so it tracks DST to
  /// within one app-open.
  Future<void> _syncTimezoneOffset() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await client.from('profiles').update({
        'tz_offset_min': DateTime.now().timeZoneOffset.inMinutes,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Timezone sync failed: $e');
    }
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenSub?.cancel();
  }
}
