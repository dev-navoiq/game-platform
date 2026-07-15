import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/env_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/game_end_ad_controller.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_bottom_sheet.dart';
import '../../lobby/models/room_member.dart';
import '../providers/game_provider.dart';
import '../providers/game_session_providers.dart';
import 'local_game_coordinator.dart';
import 'local_game_session.dart';

/// Game types that support fully on-device "Practice vs Bots".
/// Card games need per-game wire decoders + optimistic-flow wiring before
/// they can join this set — see LocalGameCoordinator.
const Set<String> practiceSupportedGameTypes = {'ludo'};

/// Ask how many bots to play against, then start a fully on-device practice
/// game and navigate to the normal game screen.
///
/// The whole session runs locally: the Dart rules engine validates/applies
/// the human's moves, bot moves come from bot_strategies with a natural
/// think delay, and NOTHING touches Supabase (the synthetic `local-` room id
/// short-circuits sendMove, the realtime subscription, the bot controller
/// and the leave-room call).
Future<void> startPracticeVsBots(
  BuildContext context,
  WidgetRef ref, {
  required String gameType,
}) async {
  if (!practiceSupportedGameTypes.contains(gameType)) return;

  final choice = await _showBotCountSheet(context);
  if (choice == null) return; // dismissed
  final (botCount, autoPilot) = choice;
  if (!context.mounted) return;

  // Interstitial slot on practice start (free tier only) — also the fastest
  // way to exercise the ad pipeline without playing a game to the end.
  await ref.read(gameEndAdControllerProvider).onPracticeStart(context);
  if (!context.mounted) return;

  // A guest/registered user is always signed in past the router redirect;
  // the fallback only matters for widget tests without Supabase.
  final humanId = ref.read(currentUserProvider)?.id ?? 'local-human';
  final roomId =
      '${LocalGameSession.roomIdPrefix}${DateTime.now().millisecondsSinceEpoch}';

  final notifier = ref.read(gameStateProvider.notifier);
  notifier.setGameType(gameType);
  ref.read(gameTypeProvider.notifier).state = gameType;

  final coordinator = LocalGameCoordinator.ludo(
    roomId: roomId,
    humanPlayerId: humanId,
    botCount: botCount,
    publish: notifier.updateState,
    autoPilot: autoPilot,
  );
  notifier.attachLocalSession(coordinator);

  // Roster so seats show "You" / bot names instead of raw ids.
  final members = <String, RoomMember>{
    humanId: RoomMember(
      id: humanId,
      displayName: autoPilot ? 'You (auto)' : 'You',
      seatIndex: 0,
      isHost: true,
      isBot: false,
      isReady: true,
      isCurrentUser: true,
    ),
  };
  var seat = 1;
  coordinator.botNamesById.forEach((id, name) {
    if (id == humanId) return; // autopilot: keep the human's own entry
    members[id] = RoomMember(
      id: id,
      displayName: name,
      seatIndex: seat++,
      isHost: false,
      isBot: true,
      isReady: true,
      isCurrentUser: false,
      botDifficulty: 'medium',
    );
  });
  ref.read(roomMembersProvider.notifier).state = members;

  // Publish the initial state before navigating so GameScreen never shows
  // its "Setting up the table…" spinner.
  coordinator.start();

  if (!context.mounted) return;
  await context.push(AppRoutes.gamePath(roomId));
}

Future<(int, bool)?> _showBotCountSheet(BuildContext context) {
  return GlassBottomSheet.show<(int, bool)>(
    context: context,
    title: 'Practice vs Bots',
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Play offline against bots — no room, no waiting. '
            'How many opponents?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final n in const [1, 2, 3])
                _BotCountChoice(
                  count: n,
                  onTap: () => Navigator.of(context).pop((n, false)),
                ),
            ],
          ),
          // Dev/staging soak-test: bots drive every seat (including yours),
          // so a full game plays itself through the real UI hands-free.
          if (!EnvConfig.isProduction) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).pop((3, true)),
              child: Text(
                'Auto-play a full game (dev)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent.withValues(alpha: 0.85),
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accent.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _BotCountChoice extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _BotCountChoice({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.45),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count == 1 ? 'bot' : 'bots',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
