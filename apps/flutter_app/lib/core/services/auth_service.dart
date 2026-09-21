import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// OAuth + password-recovery links come back into the app on the `gathr://`
  /// scheme, which is registered in Info.plist and AndroidManifest. (The old
  /// `io.supabase.gameplatform://` scheme never was, so the browser could not
  /// return to the app.) DeepLinkService ignores this host, and supabase_flutter
  /// consumes the auth params itself.
  static const oauthRedirectUri = 'gathr://login-callback/';

  /// SharedPreferences key for the last email used to sign in — prefilled on
  /// the login screen so returning players don't retype it.
  static const lastLoginEmailKey = 'last_login_email';

  /// Set when a guest kicks off an OAuth linkIdentity upgrade; the account
  /// conversion finishes out-of-band (browser → deep link), so the screens call
  /// [finalizeOAuthUpgradeIfPending] from their auth listener to grant the
  /// welcome gems once the identity is attached.
  bool _oauthUpgradePending = false;

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

  /// Launches the browser-based OAuth flow for [provider] (Google/Apple).
  ///
  /// For a signed-in guest this LINKS the identity to the existing anonymous
  /// account (same user id — coins/XP/level carry over) instead of creating a
  /// fresh user. Returns once the browser is launched; completion arrives via
  /// the `gathr://login-callback/` deep link and surfaces on
  /// [authStateChanges] (signedIn / userUpdated).
  Future<void> signInWithProvider(OAuthProvider provider) async {
    // gathr:// is for mobile only — a web browser can't "return" to a custom
    // scheme after the provider redirect. On web, Uri.base.origin brings the
    // flow back to the running app (must be in the Supabase allow list).
    final redirect = kIsWeb ? Uri.base.origin : oauthRedirectUri;
    if (isGuest) {
      _oauthUpgradePending = true;
      await _client.auth.linkIdentity(provider, redirectTo: redirect);
    } else {
      await _client.auth.signInWithOAuth(provider, redirectTo: redirect);
    }
  }

  /// Completes a guest→OAuth upgrade started by [signInWithProvider]: flips
  /// account_type to 'registered' and grants welcome gems. The edge function
  /// is idempotent. Returns true if an upgrade was finalized.
  Future<bool> finalizeOAuthUpgradeIfPending() async {
    if (!_oauthUpgradePending) return false;
    if (isGuest) return false; // link didn't complete (yet)
    _oauthUpgradePending = false;
    await _client.functions.invoke('account-upgrade');
    return true;
  }

  Future<void> signOut() async {
    // Must precede signOut: deleting the device token row needs the session
    // (RLS), and a token left behind would keep pushing to a signed-out device.
    await NotificationService.instance.unregisterCurrentToken();
    await _client.auth.signOut();
  }

  /// Emails a password-reset link that deep-links back into the app; the
  /// login screen listens for the passwordRecovery event and prompts for a
  /// new password.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: oauthRedirectUri);
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
