import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseServiceProvider));
});

class AuthService {
  final SupabaseService _supabaseService;

  AuthService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );

    // The profile row is auto-created by the handle_new_user trigger (which
    // defaults the username to an email-derived value). Apply the chosen
    // username; ignore failures (e.g. username taken) so signup still succeeds.
    if (response.user != null) {
      try {
        await _client
            .from('profiles')
            .update({'username': username}).eq('id', response.user!.id);
      } catch (_) {/* non-fatal */}
    }

    return response;
  }

  /// Convert the current anonymous (guest) account into a permanent one by
  /// linking an email + password. The user id is unchanged, so coins/XP/level
  /// carry over. Flips account_type to 'registered' and grants welcome gems via
  /// the account-upgrade edge function.
  Future<void> upgradeGuestAccount({
    required String email,
    required String password,
    required String username,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(email: email, password: password, data: {'username': username}),
    );
    final uid = currentUser?.id;
    if (uid != null) {
      try {
        await _client
            .from('profiles')
            .update({'username': username}).eq('id', uid);
      } catch (_) {/* non-fatal */}
    }
    await _client.functions.invoke('account-upgrade');
  }

  bool get isGuest => _client.auth.currentUser?.isAnonymous ?? false;

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.gameplatform://login-callback/',
    );
  }

  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.gameplatform://login-callback/',
    );
  }

  Future<void> signOut() async {
    // Must precede signOut: deleting the device token row needs the session
    // (RLS), and a token left behind would keep pushing to a signed-out device.
    await NotificationService.instance.unregisterCurrentToken();
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
