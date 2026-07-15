import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_bottom_sheet.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../../game/local/practice_launcher.dart';
import '../models/room_member.dart';
import '../presentation/widgets/room_list_card.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String gameType;

  const LobbyScreen({super.key, this.gameType = ''});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  /// Guards against a double-tap pushing two Room screens (→ two rooms). Held
  /// while the Room screen is on top; cleared when the user returns here, so a
  /// second create is allowed after backing out.
  bool _navigating = false;

  String _displayName(AppLocalizations l10n) {
    switch (widget.gameType) {
      case 'twenty_nine':
        return l10n.gameNameTwentyNine;
      case 'oh_hell':
        return l10n.gameNameOhHell;
      case 'hearts':
        return l10n.gameNameHearts;
      case 'spades':
        return l10n.gameNameSpades;
      case 'bridge':
        return l10n.gameNameBridge;
      case 'chess':
        return l10n.gameNameChess;
      case 'ludo':
        return l10n.gameNameLudo;
      case 'sequence':
        return l10n.gameNameSequence;
      default:
        return l10n.gameNameGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(title: l10n.lobbyTitle(_displayName(l10n))),
        body: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            children: [
              // Join by Code button — opens the join screen
              GlassButton(
                label: l10n.joinByCode,
                onPressed: () => context.push(AppRoutes.joinByCodePath(widget.gameType)),
                size: GlassButtonSize.large,
                width: double.infinity,
                variant: GlassButtonVariant.outlined,
                icon: const Icon(Icons.vpn_key_outlined,
                    color: Colors.white, size: 20),
              ),

              // Practice vs Bots — fully on-device game, no room/server needed.
              if (practiceSupportedGameTypes.contains(widget.gameType)) ...[
                const SizedBox(height: 12),
                GlassButton(
                  label: l10n.practiceVsBots,
                  onPressed: () =>
                      startPracticeVsBots(context, ref, gameType: widget.gameType),
                  size: GlassButtonSize.large,
                  width: double.infinity,
                  variant: GlassButtonVariant.outlined,
                  icon: const Icon(Icons.smart_toy_outlined,
                      color: Colors.white, size: 20),
                ),
              ],
              const SizedBox(height: 16),

              // Room list (placeholder — sample rooms until matchmaking is wired)
              Expanded(
                child: _RoomList(gameType: widget.gameType),
              ),

              // Banner ad (free tier only)
              const BannerAdWidget(),

              // Create Room button — navigates straight to the room, which
              // creates itself in the background so the user never waits on a
              // frozen button.
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: GlassButton(
                  label: l10n.createRoom,
                  onPressed: _onCreateRoom,
                  size: GlassButtonSize.large,
                  width: double.infinity,
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onCreateRoom() async {
    if (_navigating) return;

    // For variable-player games, ask the host how many seats to open before
    // we head to the room. This is the one thing we genuinely need up front;
    // the actual create-room call happens inside the Room screen.
    int maxPlayers = 4;
    if (widget.gameType == 'oh_hell') {
      final picked = await _showOhHellPlayerCountSheet(context);
      if (picked == null) return; // dismissed
      maxPlayers = picked;
    }
    if (!mounted) return;

    // Navigate immediately with a create request; the Room screen renders an
    // optimistic "creating…" table and fires create-room in the background.
    // `push` resolves when the user returns, so we can re-arm the guard.
    _navigating = true;
    await context.push(
      AppRoutes.roomPath(AppRoutes.pendingRoomId),
      extra: RoomCreateRequest(
        gameType: widget.gameType,
        socialMode: 'full',
        maxPlayers: maxPlayers,
      ),
    );
    if (mounted) _navigating = false;
  }

  Future<int?> _showOhHellPlayerCountSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassBottomSheet.show<int>(
      context: context,
      title: l10n.howManyPlayers,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.ohHellPlayerCountHint,
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
                for (final n in const [4, 5, 6])
                  _PlayerCountChoice(
                    count: n,
                    onTap: () => Navigator.of(context).pop(n),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCountChoice extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PlayerCountChoice({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.12),
          border: Border.all(color: AppColors.accent.withOpacity(0.45), width: 1.2),
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
              AppLocalizations.of(context).players,
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

/// Placeholder room list — shows sample rooms until real data is wired.
class _RoomList extends StatelessWidget {
  final String gameType;

  const _RoomList({required this.gameType});

  @override
  Widget build(BuildContext context) {
    // Placeholder rooms for visual demo
    final sampleRooms = [
      _SampleRoom('ABC123', 'Player1', 2, 4, 'full'),
      _SampleRoom('XYZ789', 'CardShark', 3, 4, 'chat_only'),
      _SampleRoom('QWE456', 'GameMaster', 1, 4, 'silent'),
    ];

    return ListView.separated(
      itemCount: sampleRooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final room = sampleRooms[index];
        return RoomListCard(
          roomCode: room.code,
          hostName: room.host,
          playerCount: room.players,
          maxPlayers: room.maxPlayers,
          socialMode: room.socialMode,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context)
                      .roomJoinComingSoon(room.code))),
            );
          },
        );
      },
    );
  }
}

class _SampleRoom {
  final String code;
  final String host;
  final int players;
  final int maxPlayers;
  final String socialMode;

  const _SampleRoom(this.code, this.host, this.players, this.maxPlayers, this.socialMode);
}
