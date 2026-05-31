import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_text_field.dart';

class JoinByCodeScreen extends ConsumerStatefulWidget {
  final String gameType;

  const JoinByCodeScreen({super.key, required this.gameType});

  @override
  ConsumerState<JoinByCodeScreen> createState() => _JoinByCodeScreenState();
}

class _JoinByCodeScreenState extends ConsumerState<JoinByCodeScreen> {
  final _codeController = TextEditingController();
  String? _error;
  bool _isJoining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6 || !RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
      setState(() => _error = 'Room codes are 6 letters or digits.');
      return;
    }

    setState(() {
      _error = null;
      _isJoining = true;
    });

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final result = await supabase.joinRoom(roomCode: code);
      final roomId = result['room_id'] as String?;
      if (roomId == null) {
        throw StateError('Server returned no room_id');
      }
      if (mounted) {
        context.replace(AppRoutes.roomPath(roomId));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _humanize(e));
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  String _humanize(Object error) {
    final msg = error.toString();
    if (msg.contains('not_found') || msg.contains('Room not found')) {
      return 'No room with that code. Double-check with whoever shared it.';
    }
    if (msg.contains('room_full') || msg.contains('Room is full')) {
      return 'That room is already full.';
    }
    if (msg.contains('already_started') ||
        msg.contains('Game already started')) {
      return 'That game has already started.';
    }
    if (msg.contains('blocked')) {
      return "You're blocked from this room.";
    }
    return 'Could not join: $msg';
  }

  @override
  Widget build(BuildContext context) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Join Room'),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 56 + 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Enter the 6-character room code',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textFeltMuted,
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _codeController,
                  hint: 'e.g. AB12CD',
                  prefixIcon: Icons.vpn_key_outlined,
                  errorText: _error,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(6),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  onSubmitted: (_) => _join(),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  label: _isJoining ? 'Joining…' : 'Join Room',
                  onPressed: _isJoining ? null : _join,
                  isLoading: _isJoining,
                  size: GlassButtonSize.large,
                  width: double.infinity,
                  icon: const Icon(Icons.login, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
