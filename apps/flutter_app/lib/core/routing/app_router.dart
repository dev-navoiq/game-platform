import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../di/providers.dart';
import '../services/deep_link_service.dart';
import '../services/notification_service.dart';
import '../theme/colors.dart';
import '../../shared/animations/core/animation_constants.dart';
import '../../shared/animations/core/animation_curves.dart';
import 'routes.dart';
import '../../shared/widgets/felt_background.dart';
import '../../shared/widgets/glass_nav_bar.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lobby/screens/lobby_screen.dart';
import '../../features/lobby/presentation/join_by_code_screen.dart';
import '../../features/lobby/presentation/join_by_link_screen.dart';
import '../../features/lobby/presentation/room_screen.dart';
import '../../features/lobby/models/room_member.dart';
import '../../features/game/screens/game_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/challenges/presentation/challenges_screen.dart';
import '../../features/season_pass/presentation/season_pass_screen.dart';
import '../../features/referral/presentation/referral_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/replay_screen.dart';
import '../../features/friends/presentation/add_friends_screen.dart';
import '../../features/social/presentation/notification_settings_screen.dart';
import '../../features/social/presentation/messages_screen.dart';
import '../../features/social/presentation/dm_thread_screen.dart';
import '../../features/social/providers/messaging_providers.dart';
import '../../features/social/widgets/username_claim_sheet.dart';
import '../../features/shop/presentation/subscription_screen.dart';
import '../../features/tournaments/presentation/screens/tournaments_screen.dart';
import '../../features/tournaments/presentation/screens/tournament_detail_screen.dart';
import '../../features/dev/presentation/ad_gallery_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,

    redirect: (context, state) {
      final isLoggedIn = ref.read(isLoggedInProvider);
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (state.matchedLocation == AppRoutes.splash) {
        return isLoggedIn ? AppRoutes.home : AppRoutes.login;
      }

      if (!isLoggedIn && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isAuthRoute) {
        // Guests ARE logged in but must still reach /register — it doubles as
        // the guest→registered "Save Your Progress" upgrade flow.
        final isGuestUpgrade = state.matchedLocation == AppRoutes.register &&
            (ref.read(currentUserProvider)?.isAnonymous ?? false);
        if (!isGuestUpgrade) return AppRoutes.home;
      }

      return null;
    },

    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),

      // Auth
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.shop,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ShopScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.leaderboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LeaderboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Lobby & Room (full screen). Use a fast glass fade so the
      // home → lobby → room → game flow feels snappy instead of the slow
      // default Material slide on every hop.
      GoRoute(
        path: AppRoutes.lobby,
        pageBuilder: (context, state) => _glassPage(
          state,
          LobbyScreen(gameType: state.pathParameters['gameType'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.joinByCode,
        pageBuilder: (context, state) => _glassPage(
          state,
          JoinByCodeScreen(gameType: state.pathParameters['gameType'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.room,
        pageBuilder: (context, state) => _glassPage(
          state,
          RoomScreen(
            roomId: state.pathParameters['roomId'] ?? '',
            createRequest: state.extra is RoomCreateRequest
                ? state.extra as RoomCreateRequest
                : null,
          ),
        ),
      ),

      // Game (full screen)
      GoRoute(
        path: AppRoutes.game,
        pageBuilder: (context, state) => _glassPage(
          state,
          GameScreen(roomId: state.pathParameters['gameId'] ?? ''),
        ),
      ),

      // Settings
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      // Subscription
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),

      // Feature screens
      GoRoute(
        path: AppRoutes.challenges,
        builder: (context, state) => const ChallengesScreen(),
      ),
      GoRoute(
        path: AppRoutes.seasonPass,
        builder: (context, state) => const SeasonPassScreen(),
      ),
      GoRoute(
        path: AppRoutes.referral,
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: AppRoutes.friends,
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: AppRoutes.addFriends,
        builder: (context, state) => const AddFriendsScreen(),
      ),

      // Deep-link landings
      GoRoute(
        path: AppRoutes.joinByLink,
        builder: (context, state) => JoinByLinkScreen(
          roomCode: state.pathParameters['roomCode'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.addByCode,
        builder: (context, state) => AddFriendsScreen(
          initialQuery: state.pathParameters['friendCode'],
        ),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.replay,
        builder: (context, state) => ReplayScreen(
          roomId: state.pathParameters['roomId'] ?? '',
        ),
      ),

      // Tournaments
      GoRoute(
        path: AppRoutes.tournaments,
        builder: (context, state) => const TournamentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.tournament,
        builder: (context, state) => TournamentDetailScreen(
          tournamentId: state.pathParameters['tournamentId'] ?? '',
        ),
      ),

      // Direct messages
      GoRoute(
        path: AppRoutes.messages,
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: AppRoutes.dmThread,
        builder: (context, state) => DmThreadScreen(
          otherUserId: state.pathParameters['userId'] ?? '',
        ),
      ),

      // Dev tools
      GoRoute(
        path: AppRoutes.devAds,
        builder: (context, state) => const AdGalleryScreen(),
      ),
    ],

    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );

  // Notification taps deep-link into the app; any tap that happened during
  // cold start was parked and replays as soon as this handler is set.
  NotificationService.instance.onTapRoute = router.go;

  // External deep links (gathr:// + universal links) flush once a session
  // exists — flushing earlier would lose the target to the /login redirect.
  DeepLinkService.instance.navigator = router.go;
  DeepLinkService.instance.onAuthChanged(ref.read(isLoggedInProvider));
  ref.listen(isLoggedInProvider, (_, loggedIn) {
    DeepLinkService.instance.onAuthChanged(loggedIn);
  });

  return router;
});

/// A GoRouter page that transitions in with a fast glass fade (fade + slight
/// scale), matching the "Refined Crystal" UI. Snappier than the default
/// ~300ms Material slide — see [AnimationDurations.navTransition].
CustomTransitionPage<void> _glassPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: AnimationDurations.navTransition,
    reverseTransitionDuration: AnimationDurations.navTransition,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AnimationCurves.pageFade,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MainShell extends ConsumerWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Side-effect: starts the Supabase Realtime presence channel for the
    // signed-in user. Watching it from the shell keeps it alive for the
    // whole authenticated session and tears it down on sign-out.
    ref.watch(presenceBootstrapProvider);

    // One-time username claim prompt for registered users still on an
    // auto-generated name (incl. freshly upgraded guests). Fires once the
    // profile loads; internally guarded against repeats.
    ref.listen(userProfileProvider, (previous, next) {
      if (next.valueOrNull != null && previous?.valueOrNull == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) UsernameClaimSheet.maybeShow(context, ref);
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.feltDark,
      extendBody: true,
      body: child,
      bottomNavigationBar: const _MainBottomNav(),
    );
  }
}

class _MainBottomNav extends ConsumerWidget {
  const _MainBottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/shop')) currentIndex = 1;
    if (location.startsWith('/leaderboard')) currentIndex = 2;
    if (location.startsWith('/profile')) currentIndex = 3;

    return GlassNavBar(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go(AppRoutes.home);
          case 1:
            context.go(AppRoutes.shop);
          case 2:
            context.go(AppRoutes.leaderboard);
          case 3:
            context.go(AppRoutes.profile);
        }
      },
      items: const [
        GlassNavBarItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Home',
        ),
        GlassNavBarItem(
          icon: Icons.store_outlined,
          activeIcon: Icons.store,
          label: 'Shop',
        ),
        GlassNavBarItem(
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard,
          label: 'Ranks',
        ),
        GlassNavBarItem(
          icon: Icons.person_outlined,
          activeIcon: Icons.person,
          label: 'Profile',
        ),
      ],
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Exception? error;

  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(error?.toString() ?? 'Unknown error'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
