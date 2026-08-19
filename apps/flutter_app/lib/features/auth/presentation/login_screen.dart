import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showForm = false;
  String? _emailError;
  String? _passwordError;
  bool _navigated = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _prefillRememberedEmail();
    // OAuth (and password-recovery links) complete out-of-band: the browser
    // deep-links back and supabase_flutter emits the event here. Guarded for
    // widget tests, where Supabase.instance isn't initialized.
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange
          .listen(_onAuthEvent);
    } catch (_) {/* tests / supabase not initialized */}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _prefillRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remembered = prefs.getString(AuthService.lastLoginEmailKey);
      if (remembered != null &&
          remembered.isNotEmpty &&
          mounted &&
          _emailController.text.isEmpty) {
        _emailController.text = remembered;
      }
    } catch (_) {/* non-fatal */}
  }

  Future<void> _rememberEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AuthService.lastLoginEmailKey, email);
    } catch (_) {/* non-fatal */}
  }

  void _onAuthEvent(AuthState state) {
    if (!mounted) return;
    // The register screen may be stacked on top and owns its own completion.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    switch (state.event) {
      case AuthChangeEvent.passwordRecovery:
        _promptNewPassword();
      case AuthChangeEvent.signedIn:
        if (state.session != null) _completeSignIn(state.session!.user.email);
      default:
        break;
    }
  }

  bool _validateForm() {
    final emailError = Validators.email(_emailController.text);
    final passwordError = Validators.password(_passwordController.text);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  /// Single exit point for every successful sign-in path (guest, email,
  /// tester, OAuth deep-link return).
  Future<void> _completeSignIn(String? email) async {
    if (_navigated || !mounted) return;
    _navigated = true;
    await _rememberEmail(email);
    try {
      await ref.read(authServiceProvider).finalizeOAuthUpgradeIfPending();
    } catch (_) {/* idempotent server-side; profile refresh covers retries */}
    // Let the platform password manager offer to save the credentials.
    TextInput.finishAutofillContext();
    if (!mounted) return;
    ref.read(isLoggedInProvider.notifier).state = true;
    context.go(AppRoutes.home);
  }

  Future<void> _loginAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      await supabase.signInAsGuest();
      if (mounted) await _completeSignIn(null);
    } catch (e) {
      _showError('Guest sign-in failed', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithEmail() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final email = _emailController.text.trim();
      await supabase.signInWithEmail(
        email: email,
        password: _passwordController.text,
      );
      if (mounted) await _completeSignIn(email);
    } catch (e) {
      _showError('Email sign-in failed', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithProvider(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      // Returns once the browser opens; the session lands via deep link and
      // _onAuthEvent finishes the job.
      await ref.read(authServiceProvider).signInWithProvider(provider);
    } catch (e) {
      _showError(
          '${provider == OAuthProvider.apple ? 'Apple' : 'Google'} sign-in failed',
          e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.feltDark,
        title: const Text('Reset password',
            style: TextStyle(color: AppColors.textOnFelt)),
        content: GlassTextField(
          controller: controller,
          label: 'Email',
          hint: 'Enter your email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    if (Validators.email(email) != null) {
      _showError('Reset failed', 'Invalid email address');
      return;
    }
    try {
      await ref.read(authServiceProvider).resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showError('Reset failed', e);
    }
  }

  /// Shown when the app is opened from a password-reset email (the recovery
  /// session is already active at this point).
  Future<void> _promptNewPassword() async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.feltDark,
        title: const Text('Choose a new password',
            style: TextStyle(color: AppColors.textOnFelt)),
        content: GlassTextField(
          controller: controller,
          label: 'New password',
          hint: 'At least 8 characters',
          prefixIcon: Icons.lock_outlined,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newPassword == null) return;
    final error = Validators.password(newPassword);
    if (error != null) {
      _showError('Password not updated', error);
      return;
    }
    try {
      await ref.read(authServiceProvider).updatePassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated — you are signed in'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _completeSignIn(ref.read(authServiceProvider).currentUser?.email);
    } catch (e) {
      _showError('Password not updated', e);
    }
  }

  // ── Tester quick sign-in (dev/staging builds only) ────────────────────────

  bool get _showTesterLogin {
    try {
      return !EnvConfig.isProduction;
    } catch (_) {
      return false; // EnvConfig not initialized (widget tests)
    }
  }

  void _showTesterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.feltDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Tester accounts (staging)',
                style: TextStyle(
                  color: AppColors.textOnFelt,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            for (var i = 1; i <= 10; i++)
              ListTile(
                dense: true,
                leading:
                    const Icon(Icons.bug_report_outlined, color: AppColors.accent),
                title: Text(
                  'tester${i.toString().padLeft(2, '0')}@gathr.test',
                  style: const TextStyle(color: AppColors.textOnFelt),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _loginAsTester('tester${i.toString().padLeft(2, '0')}@gathr.test');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginAsTester(String email) async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      await supabase.signInWithEmail(email: email, password: 'GathrTest!23');
      if (mounted) await _completeSignIn(email);
    } catch (e) {
      _showError('Tester sign-in failed', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String label, Object error) {
    debugPrint('$label: $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: ${_friendlyAuthMessage(error)}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Raw AuthApiException dumps read as developer noise ("AuthApiException:
  /// invalid_credentials, statusCode: 400"). Players get plain words; the
  /// full exception still goes to debugPrint above.
  String _friendlyAuthMessage(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Email or password is incorrect, or this account no longer exists.';
        case 'email_not_confirmed':
          return 'Please confirm your email first — check your inbox.';
        case 'user_banned':
          return 'This account has been suspended.';
        case 'over_request_rate_limit':
          return 'Too many attempts — please wait a minute and try again.';
      }
      return error.message;
    }
    return 'Something went wrong. Please check your connection and try again.';
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
                    // Logo / Title
                    Icon(
                      Icons.casino,
                      size: 64,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gathr',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                            color: AppColors.textOnFelt,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cards, Strategy & Friends',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.textFeltMuted),
                    ),
                    const SizedBox(height: 48),

                    if (!_showForm) ...[
                      GlassButton(
                        label: 'Continue as Guest',
                        onPressed: _isLoading ? null : _loginAsGuest,
                        isLoading: _isLoading,
                        size: GlassButtonSize.large,
                        width: double.infinity,
                        icon: const Icon(Icons.person_outline,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 20),
                      _orDivider('or'),
                      const SizedBox(height: 20),
                      if (isIos) ...[
                        GlassButton(
                          key: const Key('apple-login-button'),
                          label: 'Continue with Apple',
                          onPressed: _isLoading
                              ? null
                              : () => _loginWithProvider(OAuthProvider.apple),
                          variant: GlassButtonVariant.outlined,
                          size: GlassButtonSize.large,
                          width: double.infinity,
                          icon: const Icon(Icons.apple,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 12),
                      ],
                      GlassButton(
                        key: const Key('google-login-button'),
                        label: 'Continue with Google',
                        onPressed: _isLoading
                            ? null
                            : () => _loginWithProvider(OAuthProvider.google),
                        variant: GlassButtonVariant.outlined,
                        size: GlassButtonSize.large,
                        width: double.infinity,
                        icon: _googleGlyph(),
                      ),
                      const SizedBox(height: 12),
                      GlassButton(
                        label: 'Sign In',
                        onPressed: () => setState(() => _showForm = true),
                        variant: GlassButtonVariant.outlined,
                        size: GlassButtonSize.large,
                        width: double.infinity,
                        icon: Icon(Icons.email_outlined,
                            color: AppColors.accent, size: 20),
                      ),
                    ],

                    if (_showForm)
                      AutofillGroup(
                        child: Column(
                          children: [
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
                              hint: 'Enter your password',
                              errorText: _passwordError,
                              prefixIcon: Icons.lock_outlined,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  _isLoading ? null : _loginWithEmail(),
                              onChanged: (_) {
                                if (_passwordError != null) {
                                  setState(() => _passwordError = null);
                                }
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : _forgotPassword,
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GlassButton(
                              label: 'Login',
                              onPressed: _isLoading ? null : _loginWithEmail,
                              isLoading: _isLoading,
                              size: GlassButtonSize.large,
                              width: double.infinity,
                            ),
                            const SizedBox(height: 8),
                            GlassButton(
                              label: 'Back',
                              onPressed: () => setState(() {
                                _showForm = false;
                                _emailError = null;
                                _passwordError = null;
                              }),
                              variant: GlassButtonVariant.ghost,
                              color: AppColors.textOnFelt,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    GlassButton(
                      label: 'Create Account',
                      onPressed: () => context.push(AppRoutes.register),
                      variant: GlassButtonVariant.ghost,
                      color: AppColors.accent,
                    ),
                    if (_showTesterLogin) ...[
                      const SizedBox(height: 4),
                      GlassButton(
                        label: 'Tester sign-in',
                        onPressed: _isLoading ? null : _showTesterSheet,
                        variant: GlassButtonVariant.ghost,
                        color: AppColors.textFeltMuted,
                        icon: const Icon(Icons.bug_report_outlined,
                            color: AppColors.textFeltMuted, size: 16),
                      ),
                    ],
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
