import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_container.dart';

/// Landing screen for /join/:code deep links (share links, gathr:// scheme).
/// Joins immediately and forwards to the room; failures land on a friendly
/// error card instead of a dead end — link taps happen outside any app
/// context where a snackbar would make sense.
class JoinByLinkScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const JoinByLinkScreen({super.key, required this.roomCode});

  @override
  ConsumerState<JoinByLinkScreen> createState() => _JoinByLinkScreenState();
}

class _JoinByLinkScreenState extends ConsumerState<JoinByLinkScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final result =
          await supabase.joinRoom(roomCode: widget.roomCode.toUpperCase());
      final roomId = result['room_id'] as String?;
      if (!mounted) return;
      if (roomId == null) {
        setState(() => _error = 'Something went wrong joining the room.');
        return;
      }
      context.replace(AppRoutes.roomPath(roomId));
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() {
        if (message.contains('not_found')) {
          _error = "This room doesn't exist anymore.";
        } else if (message.contains('room_full')) {
          _error = 'This room is already full.';
        } else if (message.contains('already_started')) {
          _error = 'This game has already started.';
        } else if (message.contains('blocked')) {
          _error = "You can't join this room.";
        } else {
          _error = "Couldn't join — check your connection and try again.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: _error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Joining room ${widget.roomCode.toUpperCase()}…',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textOnFelt,
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.meeting_room_outlined,
                            size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent),
                          onPressed: () => context.go(AppRoutes.home),
                          child: const Text('Back to home'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
