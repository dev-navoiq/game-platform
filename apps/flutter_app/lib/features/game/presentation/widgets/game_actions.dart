import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../providers/game_provider.dart';

/// Action buttons panel for the game screen (leave, settings, etc.).
///
/// For non-spectator players, "Leave" is labeled "Forfeit" and triggers a
/// server-side `leave-room` call before navigation. The edge function
/// substitutes the human's slot with a bot (so the table keeps moving for
/// other humans) and tracks the forfeit so the player can rejoin from the
/// home screen later. See memory: voice-tiering-strategy siblings — the
/// slot-persistence primitive.
class GameActions extends ConsumerWidget {
  final VoidCallback? onLeave;
  final VoidCallback? onSettings;
  final bool isSpectator;

  const GameActions({
    super.key,
    this.onLeave,
    this.onSettings,
    this.isSpectator = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassButton(
          label: isSpectator ? 'Leave' : 'Forfeit',
          onPressed: () => _confirmLeave(context, ref),
          variant: GlassButtonVariant.outlined,
          size: GlassButtonSize.small,
        ),
        if (onSettings != null) ...[
          const SizedBox(width: 8),
          GlassButton(
            label: 'Settings',
            onPressed: onSettings,
            variant: GlassButtonVariant.ghost,
            size: GlassButtonSize.small,
          ),
        ],
      ],
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    if (isSpectator) {
      // Spectators have nothing to forfeit. Server still tracks their slot
      // (so the spectator cap is freed) — fire-and-forget the call.
      _dispatchLeave(ref, reason: 'left');
      onLeave?.call();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.feltMid,
        title: Text(
          'Forfeit Game?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'A bot will take over your seat so others can keep playing. '
          'You can rejoin from the home screen.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Stay', style: GoogleFonts.inter(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Forfeit',
                style: GoogleFonts.inter(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // We dispatch leave-room and navigate in parallel. Awaiting the round
    // trip before popping would leave the user staring at the game UI for
    // ~300-600ms on a slow connection. The server is idempotent (a second
    // call returns `already_left=true`), so a network failure here doesn't
    // wedge the room — but the table animation can lag if the user pops
    // before nav lands. Trading that for a snappier pop because the table
    // animation isn't the user-perceived outcome — the home screen showing
    // up is.
    _dispatchLeave(ref, reason: 'forfeited');
    if (!context.mounted) return;
    // Forfeit routes to home, not Navigator.pop. Pop would land on whatever
    // is below (lobby for that game, or the create-room screen) — which the
    // user just abandoned and would have to back out of. `context.go` wipes
    // the route stack so the user is back at a clean starting point.
    context.go(AppRoutes.home);
  }

  /// Fire-and-forget the leave-room edge function. Logs but does not surface
  /// failures — if the call drops, the room is still safe to leave (the
  /// server's heartbeat sweep would eventually clean up, and the user can
  /// always retry by visiting the room again).
  void _dispatchLeave(WidgetRef ref, {required String reason}) {
    final roomId = ref.read(currentRoomIdProvider);
    if (roomId == null) {
      // GameScreen.initState hadn't published the room id yet (race during
      // very fast navigation). Skip — the row stays in the DB, the user
      // can resume from the home screen and forfeit again.
      return;
    }
    final supabase = ref.read(supabaseServiceProvider);
    supabase.leaveRoom(roomId: roomId, reason: reason).catchError((error) {
      // ignore: avoid_print — surfaces on flutter run in release.
      print('[GameActions] leaveRoom failed: $error');
    });
  }
}

/// Reusable forfeit/leave handler so the HUD icon (top-right) can trigger
/// the same flow as the legacy bottom GameActions row. Pops a confirm
/// dialog (skipped for spectators), dispatches leave-room, and navigates
/// home so the user doesn't land back on the lobby they just abandoned.
Future<void> confirmAndForfeitGame(
  BuildContext context,
  WidgetRef ref, {
  required bool isSpectator,
}) async {
  void dispatch(String reason) {
    final roomId = ref.read(currentRoomIdProvider);
    if (roomId == null) return;
    final supabase = ref.read(supabaseServiceProvider);
    supabase.leaveRoom(roomId: roomId, reason: reason).catchError((error) {
      // ignore: avoid_print
      print('[confirmAndForfeitGame] leaveRoom failed: $error');
    });
  }

  if (isSpectator) {
    dispatch('left');
    if (context.mounted) context.go(AppRoutes.home);
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.feltMid,
      title: Text(
        'Forfeit Game?',
        style: GoogleFonts.poppins(color: Colors.white),
      ),
      content: Text(
        'A bot will take over your seat so others can keep playing. '
        'You can rejoin from the home screen.',
        style: GoogleFonts.inter(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Stay', style: GoogleFonts.inter(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Forfeit',
            style: GoogleFonts.inter(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  dispatch('forfeited');
  if (!context.mounted) return;
  context.go(AppRoutes.home);
}
