import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/colors.dart';
import '../../friends/data/discovery_repository.dart';

/// One-time "claim your username" sheet for registered users still carrying
/// an auto-generated name. Also the claim moment for converting guests,
/// since upgrades keep the same user id. Skippable; server trigger owns the
/// real validation (format, reserved, uniqueness, 30-day rename cooldown).
class UsernameClaimSheet extends ConsumerStatefulWidget {
  const UsernameClaimSheet({super.key});

  static const _promptedKey = 'username_claim_prompted';

  /// Show at most once per install for eligible users. Call after the
  /// profile has loaded; no-ops for guests and already-claimed users.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null || profile.isGuest || profile.usernameClaimedAt != null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_promptedKey) ?? false) return;
    await prefs.setBool(_promptedKey, true);
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const UsernameClaimSheet(),
    );
  }

  @override
  ConsumerState<UsernameClaimSheet> createState() => _UsernameClaimSheetState();
}

class _UsernameClaimSheetState extends ConsumerState<UsernameClaimSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  static final _valid = RegExp(r'^[a-z0-9][a-z0-9_]{2,19}$');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final username = _controller.text.trim().toLowerCase();
    if (!_valid.hasMatch(username)) {
      setState(() =>
          _error = '3-20 characters: a-z, 0-9, underscore (no leading _)');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(discoveryRepositoryProvider).claimUsername(username);
      ref.invalidate(userProfileProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You're @$username now!")),
        );
      }
    } on PostgrestException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.code == '23505'
            ? 'That username is taken'
            : e.message;
      });
    } catch (_) {
      setState(() {
        _submitting = false;
        _error = "Couldn't save — check your connection";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.feltDark.withOpacity(0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Claim your username',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnFelt,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "It's how friends find you in search. You can change it once every 30 days.",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textFeltMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                style: GoogleFonts.inter(
                    fontSize: 16, color: AppColors.textOnFelt),
                decoration: InputDecoration(
                  prefixText: '@',
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 16, color: AppColors.accent),
                  hintText: 'username',
                  hintStyle:
                      GoogleFonts.inter(color: AppColors.textFeltMuted),
                  errorText: _error,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _claim(),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Maybe later',
                      style: GoogleFonts.inter(color: AppColors.textFeltMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: _submitting ? null : _claim,
                    child: const Text('Claim'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
