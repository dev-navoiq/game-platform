import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'screens/tournaments_screen.dart';
import 'screens/create_tournament_screen.dart';
import 'screens/templates_screen.dart';
import 'screens/economy_config_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/tournaments',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final loggedIn = ref.read(sessionProvider) != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';

      // M5 — gate on ADMIN status, not merely "has a session". The console is a
      // public Firebase Hosting URL sharing the same Supabase auth pool as the
      // game app, so a plain game account must not reach admin screens even
      // though server-side RLS/edge functions are the real defense.
      final adminAsync = ref.read(isAdminProvider);
      if (adminAsync.isLoading) {
        // Hold at /login until the allow-list check resolves; the refresh
        // listenable re-runs this redirect when isAdminProvider settles.
        return atLogin ? null : '/login';
      }
      final isAdmin = adminAsync.valueOrNull ?? false;
      if (!isAdmin) return atLogin ? null : '/login';
      if (atLogin) return '/tournaments';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/tournaments',
            builder: (_, __) => const TournamentsScreen(),
          ),
          GoRoute(
            path: '/tournaments/new',
            builder: (_, __) => const CreateTournamentScreen(),
          ),
          GoRoute(
            path: '/templates',
            builder: (_, __) => const TemplatesScreen(),
          ),
          GoRoute(
            path: '/economy',
            builder: (_, __) => const EconomyConfigScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod auth changes to GoRouter's Listenable refresh. Also listens
/// to the admin allow-list check so the redirect re-runs once it resolves.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(isAdminProvider, (_, __) => notifyListeners());
  }
}
