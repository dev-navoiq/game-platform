class AppRoutes {
  AppRoutes._();

  // Auth
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';

  // Main (shell)
  static const home = '/home';
  static const profile = '/profile';
  static const settings = '/settings';
  static const shop = '/shop';
  static const subscription = '/subscription';
  static const leaderboard = '/leaderboard';

  // Settings sub-routes
  static const notificationSettings = '/settings/notifications';

  // Features
  static const favorites = '/favorites';
  static const history = '/history';
  static const challenges = '/challenges';
  static const seasonPass = '/season-pass';
  static const referral = '/referral';
  static const friends = '/friends';

  // Lobby
  static const lobby = '/lobby/:gameType';
  static const joinByCode = '/lobby/:gameType/join';
  static const room = '/room/:roomId';

  // Game
  static const game = '/game/:gameId';

  // Replay
  static const replay = '/replay/:roomId';

  // Tournaments
  static const tournaments = '/tournaments';
  static const tournament = '/tournament/:tournamentId';

  // Helpers
  static String lobbyPath(String gameType) => '/lobby/$gameType';
  static String joinByCodePath(String gameType) => '/lobby/$gameType/join';
  static String roomPath(String roomId) => '/room/$roomId';
  static String gamePath(String gameId) => '/game/$gameId';
  static String replayPath(String roomId) => '/replay/$roomId';
  static String tournamentPath(String tournamentId) =>
      '/tournament/$tournamentId';
}
