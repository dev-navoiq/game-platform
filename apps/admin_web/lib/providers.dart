import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/admin_api.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(supabaseClientProvider));
});

/// Emits on every auth state change (login / logout / token refresh) so the
/// router can react.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The current session, recomputed on each auth change.
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});

/// Whether the signed-in user is on the admin allow-list. Null while loading.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return false;
  return ref.watch(adminApiProvider).amIAdmin();
});

/// Tournament list (admin console view). Refreshable via `ref.invalidate`.
final tournamentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminApiProvider).listTournaments();
});

/// The single economy_config row.
final economyConfigProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(adminApiProvider).getEconomyConfig();
});
