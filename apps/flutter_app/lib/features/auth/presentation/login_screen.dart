import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> _loginAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      await supabase.signInAsGuest();
      if (mounted) {
        ref.read(isLoggedInProvider.notifier).state = true;
        context.go(AppRoutes.home);
      }
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
      await supabase.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        ref.read(isLoggedInProvider.notifier).state = true;
        context.go(AppRoutes.home);
      }
    } catch (e) {
      _showError('Email sign-in failed', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String label, Object error) {
    debugPrint('$label: $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: $error'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      'Game Platform',
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
                      const SizedBox(height: 16),
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

                    if (_showForm) ...[
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
                        hint: 'Enter your password',
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

                    const SizedBox(height: 16),
                    GlassButton(
                      label: 'Create Account',
                      onPressed: () => context.push(AppRoutes.register),
                      variant: GlassButtonVariant.ghost,
                      color: AppColors.accent,
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
