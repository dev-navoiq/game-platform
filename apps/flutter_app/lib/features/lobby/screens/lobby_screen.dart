import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_bottom_sheet.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../presentation/widgets/room_list_card.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String gameType;

  const LobbyScreen({super.key, this.gameType = ''});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  /// Tracks an in-flight create-room request so the button can show a
  /// spinner and reject repeat taps. Without this guard, the create-room
  /// edge function can race and produce two rooms for a single intent.
  bool _isCreating = false;

  String get _displayName {
    switch (widget.gameType) {
      case 'twenty_nine':
        return 'Twenty-Nine';
      case 'oh_hell':
        return 'Oh Hell';
      case 'hearts':
        return 'Hearts';
      case 'spades':
        return 'Spades';
      case 'bridge':
        return 'Bridge';
      case 'chess':
        return 'Chess';
      case 'ludo':
        return 'Ludo';
      case 'sequence':
        return 'Sequence';
      default:
        return 'Game';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(title: '$_displayName Lobby'),
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
                label: 'Join by Code',
                onPressed: () => context.push(AppRoutes.joinByCodePath(widget.gameType)),
                size: GlassButtonSize.large,
                width: double.infinity,
                variant: GlassButtonVariant.outlined,
                icon: const Icon(Icons.vpn_key_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(height: 16),

              // Room list (placeholder — sample rooms until matchmaking is wired)
              Expanded(
                child: _RoomList(gameType: widget.gameType),
              ),

              // Banner ad (free tier only)
              const BannerAdWidget(),

              // Create Room button — disables itself + shows a spinner while
              // the edge function call is in flight so impatient retaps don't
              // spawn duplicate rooms.
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: GlassButton(
                  label: _isCreating ? 'Creating Room…' : 'Create Room',
                  onPressed: _isCreating ? null : _onCreateRoom,
                  isLoading: _isCreating,
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
    if (_isCreating) return;

    // For variable-player games, ask the host how many seats to open before
    // we actually create the room. The picker is shown before _isCreating
    // flips so a dismissed sheet doesn't leave the button spinning.
    int maxPlayers = 4;
    if (widget.gameType == 'oh_hell') {
      final picked = await _showOhHellPlayerCountSheet(context);
      if (picked == null) return; // dismissed
      maxPlayers = picked;
    }

    setState(() => _isCreating = true);

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final result = await supabase.createRoom(
        gameType: widget.gameType,
        socialMode: 'full',
        maxPlayers: maxPlayers,
      );
      if (mounted) {
        context.push(AppRoutes.roomPath(result['room_id'] as String));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create room: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<int?> _showOhHellPlayerCountSheet(BuildContext context) {
    return GlassBottomSheet.show<int>(
      context: context,
      title: 'How many players?',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Oh Hell needs 4 to 6 players. You can add bots in the room.',
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
              'players',
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
              SnackBar(content: Text('Room ${room.code} — join via code coming soon')),
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
