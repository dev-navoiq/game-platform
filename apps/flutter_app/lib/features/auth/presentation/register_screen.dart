import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_text_field.dart';

/// Create-account screen. Doubles as the guest→registered upgrade flow: when
/// the current user is anonymous, linking an email (or a Google/Apple
/// identity) keeps the same user id (so coins/XP/level carry over) and grants
/// the welcome gems.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  bool _navigated = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // OAuth sign-up / guest identity-linking completes out-of-band (browser →
    // deep link); supabase_flutter surfaces it here. Guarded for widget tests.
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange
          .listen(_onAuthEvent);
    } catch (_) {/* tests / supabase not initialized */}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthEvent(AuthState state) {
    if (!mounted || _navigated) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final event = state.event;
    // signedIn: fresh OAuth sign-up. userUpdated: guest linkIdentity landed.
    if (event != AuthChangeEvent.signedIn &&
        event != AuthChangeEvent.userUpdated) {
      return;
    }
    final user = state.session?.user;
    if (user == null || user.isAnonymous) return;
    _completeSignUp(email: user.email, checkOAuthUpgrade: true);
  }

  bool _validate() {
    final username = _usernameController.text.trim();
    final usernameError =
        username.length < 3 ? 'Username must be at least 3 characters' : null;
    final emailError = Validators.email(_emailController.text);
    final passwordError = Validators.password(_passwordController.text);
    setState(() {
      _usernameError = usernameError;
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return usernameError == null && emailError == null && passwordError == null;
  }

  Future<void> _rememberEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AuthService.lastLoginEmailKey, email);
    } catch (_) {/* non-fatal */}
  }

  /// Single exit point for every successful path (email form + OAuth return).
  Future<void> _completeSignUp({
    String? email,
    bool welcomeGems = false,
    bool checkOAuthUpgrade = false,
  }) async {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (checkOAuthUpgrade) {
      try {
        welcomeGems = await ref
                .read(authServiceProvider)
                .finalizeOAuthUpgradeIfPending() ||
            welcomeGems;
      } catch (_) {/* idempotent server-side */}
    }

    await _rememberEmail(email);
    TextInput.finishAutofillContext();
    if (!mounted) return;
    // Refresh the profile so real balance / account_type flow through.
    ref.invalidate(userProfileProvider);
    ref.read(isLoggedInProvider.notifier).state = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(welcomeGems
            ? 'Account created — welcome gems added!'
            : 'Account created!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go(AppRoutes.home);
  }

  Future<void> _submit({required bool isUpgrade}) async {
    if (!_validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (isUpgrade) {
        await auth.upgradeGuestAccount(
          email: email,
          password: password,
          username: username,
        );
      } else {
        await auth.signUpWithEmail(
          email: email,
          password: password,
          username: username,
        );
      }

      if (!mounted) return;
      // upgradeGuestAccount already invoked account-upgrade (welcome gems).
      await _completeSignUp(email: email, welcomeGems: isUpgrade);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-up failed: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithProvider(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      // For guests this LINKS the identity (progress carries over); completion
      // arrives via deep link in _onAuthEvent.
      await ref.read(authServiceProvider).signInWithProvider(provider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${provider == OAuthProvider.apple ? 'Apple' : 'Google'} sign-up failed: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _orDivider(String label) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.textFeltMuted.withOpacity(0.4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: TextStyle(color: AppColors.textFeltMuted, fontSize: 13)),
        ),
        Expanded(child: Divider(color: AppColors.textFeltMuted.withOpacity(0.4))),
      ],
    );
  }

  Widget _googleGlyph() {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.read(authServiceProvider).isGuest;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      backgroundColor: AppColors.feltDark,
      body: FeltBackground(
        showAmbientGlow: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add_alt_1,
                        size: 56, color: AppColors.accent),
                    const SizedBox(height: 16),
                    Text(
                      isGuest ? 'Save Your Progress' : 'Create Account',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: AppColors.textOnFelt,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isGuest
                          ? 'Link an email to keep your coins & level forever, and unlock gems, friends and tournaments.'
                          : 'Join to earn gems, add friends and enter tournaments.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textFeltMuted),
                    ),
                    const SizedBox(height: 32),
                    AutofillGroup(
                      child: Column(
                        children: [
                          GlassTextField(
                            key: const Key('username-field'),
                            controller: _usernameController,
                            label: 'Username',
                            hint: 'Choose a username',
                            errorText: _usernameError,
                            prefixIcon: Icons.badge_outlined,
                            autofillHints: const [AutofillHints.newUsername],
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_usernameError != null) {
                                setState(() => _usernameError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          GlassTextField(
                            key: const Key('email-field'),
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Enter your email',
                            errorText: _emailError,
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          GlassTextField(
                            key: const Key('password-field'),
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Create a password',
                            errorText: _passwordError,
                            prefixIcon: Icons.lock_outlined,
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _isLoading
                                ? null
                                : _submit(isUpgrade: isGuest),
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GlassButton(
                      label: isGuest ? 'Save Account' : 'Create Account',
                      onPressed:
                          _isLoading ? null : () => _submit(isUpgrade: isGuest),
                      isLoading: _isLoading,
                      size: GlassButtonSize.large,
                      width: double.infinity,
                    ),
                    const SizedBox(height: 20),
                    _orDivider('or continue with'),
                    const SizedBox(height: 20),
                    if (isIos) ...[
                      GlassButton(
                        key: const Key('apple-register-button'),
                        label: isGuest ? 'Save with Apple' : 'Continue with Apple',
                        onPressed: _isLoading
                            ? null
                            : () => _signUpWithProvider(OAuthProvider.apple),
                        variant: GlassButtonVariant.outlined,
                        size: GlassButtonSize.large,
                        width: double.infinity,
                        icon: const Icon(Icons.apple,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GlassButton(
                      key: const Key('google-register-button'),
                      label: isGuest ? 'Save with Google' : 'Continue with Google',
                      onPressed: _isLoading
                          ? null
                          : () => _signUpWithProvider(OAuthProvider.google),
                      variant: GlassButtonVariant.outlined,
                      size: GlassButtonSize.large,
                      width: double.infinity,
                      icon: _googleGlyph(),
                    ),
                    const SizedBox(height: 8),
                    GlassButton(
                      label: 'Back',
                      onPressed: () => context.pop(),
                      variant: GlassButtonVariant.ghost,
                      color: AppColors.textOnFelt,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
