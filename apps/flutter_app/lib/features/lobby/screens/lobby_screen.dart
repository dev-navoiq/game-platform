import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_text_field.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../presentation/widgets/room_list_card.dart';

class LobbyScreen extends ConsumerWidget {
  final String gameType;

  const LobbyScreen({super.key, this.gameType = ''});

  String get _displayName {
    switch (gameType) {
      case 'twenty_nine':
        return 'Twenty-Nine';
      case 'oh_hell':
        return 'Oh Hell';
      case 'hearts':
        return 'Hearts';
      case 'spades':
        return 'Spades';
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
  Widget build(BuildContext context, WidgetRef ref) {
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
              // Search bar
              GlassTextField(
                hint: 'Search rooms by code...',
                prefixIcon: Icons.search,
              ),
              const SizedBox(height: 16),

              // Room list
              Expanded(
                child: _RoomList(gameType: gameType),
              ),

              // Banner ad (free tier only)
              const BannerAdWidget(),

              // Create Room button
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: GlassButton(
                  label: 'Create Room',
                  onPressed: () async {
                    final supabase = ref.read(supabaseServiceProvider);
                    final result = await supabase.createRoom(
                      gameType: gameType,
                      socialMode: 'full',
                    );
                    if (context.mounted) {
                      context.push(AppRoutes.roomPath(result['room_id'] as String));
                    }
                  },
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
