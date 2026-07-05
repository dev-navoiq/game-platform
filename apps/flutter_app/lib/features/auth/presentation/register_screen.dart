import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_text_field.dart';

/// Create-account screen. Doubles as the guest→registered upgrade flow: when
/// the current user is anonymous, linking an email keeps the same user id (so
/// coins/XP/level carry over) and grants the welcome gems.
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

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      // Refresh the profile so real balance / account_type flow through.
      ref.invalidate(userProfileProvider);
      ref.read(isLoggedInProvider.notifier).state = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUpgrade
              ? 'Account created — welcome gems added!'
              : 'Account created!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go(AppRoutes.home);
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

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.read(authServiceProvider).isGuest;

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
                    GlassTextField(
                      key: const Key('username-field'),
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'Choose a username',
                      errorText: _usernameError,
                      prefixIcon: Icons.badge_outlined,
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
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
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
