import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Inbound deep links: `gathr://join/CODE` custom scheme and
/// `https://<link domain>/join/CODE` universal/app links.
///
/// Links can arrive before the router exists (cold start) or before auth
/// resolves (the router would redirect to /login and lose the target), so
/// the latest link is parked and flushed once both a navigator and a
/// session are present. Guests keep their link through registration for
/// the same reason — the park survives until a logged-in flush.
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  /// HTTPS base for outbound share links. Piggybacks on the Firebase
  /// Hosting site that serves the AASA/assetlinks association files —
  /// swap to the branded domain (plus manifest/entitlement entries) when
  /// one is purchased.
  static const linkBase = 'https://game-platform-staging.web.app';

  static String joinLink(String roomCode) => '$linkBase/join/$roomCode';
  static String addFriendLink(String friendCode) =>
      '$linkBase/add/${friendCode.replaceAll('-', '')}';

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  String? _pendingRoute;
  bool _loggedIn = false;
  void Function(String route)? _navigate;

  Future<void> initialize() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
      _sub = _appLinks.uriLinkStream.listen(_handleUri);
    } catch (e) {
      debugPrint('DeepLinkService init failed: $e');
    }
  }

  set navigator(void Function(String route) nav) {
    _navigate = nav;
    _flush();
  }

  // ignore: avoid_positional_boolean_parameters
  void onAuthChanged(bool loggedIn) {
    _loggedIn = loggedIn;
    _flush();
  }

  void _handleUri(Uri uri) {
    final route = routeFor(uri);
    if (route == null) return;
    _pendingRoute = route;
    _flush();
  }

  void _flush() {
    final route = _pendingRoute;
    final nav = _navigate;
    if (route == null || nav == null || !_loggedIn) return;
    _pendingRoute = null;
    nav(route);
  }

  /// Maps an external URI onto an internal route. Visible for tests.
  ///
  /// Handles both shapes:
  ///   gathr://join/AB12CD          (host carries the verb)
  ///   https://host/join/AB12CD     (path carries the verb)
  @visibleForTesting
  static String? routeFor(Uri uri) {
    final parts = uri.scheme == 'gathr'
        ? [uri.host, ...uri.pathSegments]
        : uri.pathSegments;
    if (parts.length < 2) return null;

    final verb = parts[0].toLowerCase();
    final arg = Uri.encodeComponent(parts[1]);
    switch (verb) {
      case 'join':
        return '/join/$arg';
      case 'add':
        return '/add/$arg';
      case 't':
        return '/tournament/$arg';
      default:
        return null;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
