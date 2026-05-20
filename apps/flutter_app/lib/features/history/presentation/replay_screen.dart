import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../providers/history_providers.dart';

/// Replay data provider for a specific room.
final replayDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, roomId) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo == null) return null;
  return repo.getGameReplay(roomId);
});

class ReplayScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ReplayScreen({super.key, required this.roomId});

  @override
  ConsumerState<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends ConsumerState<ReplayScreen> {
  int _currentMoveIndex = 0;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final replayAsync = ref.watch(replayDataProvider(widget.roomId));

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Game Replay'),
        body: replayAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Failed to load replay',
                style: TextStyle(color: Colors.white70)),
          ),
          data: (data) {
            if (data == null) {
              return const Center(
                child: Text(
                  'Replay data not available',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              );
            }

            final gameInfo =
                data['game_info'] as Map<String, dynamic>;
            final moves = data['moves'] as List;
            final totalMoves = moves.length;

            return Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 56 + 16,
                left: 16,
                right: 16,
                bottom: 24,
              ),
              child: Column(
                children: [
                  // Game info card
                  GlassContainer(
                    borderRadius: 14,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(
                              gameInfo['game_type'] as String? ?? ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Move ${_currentMoveIndex + 1} of $totalMoves',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Replay viewport (placeholder)
                  Expanded(
                    child: GlassContainer(
                      borderRadius: 14,
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.replay_circle_filled,
                                size: 64,
                                color: Colors.white.withOpacity(0.15)),
                            const SizedBox(height: 16),
                            Text(
                              totalMoves > 0
                                  ? 'Move ${_currentMoveIndex + 1}'
                                  : 'No moves recorded',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (totalMoves > 0 &&
                                _currentMoveIndex < totalMoves) ...[
                              const SizedBox(height: 8),
                              Text(
                                _describeMoveAt(
                                    moves, _currentMoveIndex),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Playback controls
                  GlassContainer(
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // First move
                        IconButton(
                          icon: const Icon(Icons.skip_previous,
                              color: Colors.white),
                          onPressed: totalMoves > 0
                              ? () => setState(
                                  () => _currentMoveIndex = 0)
                              : null,
                        ),
                        // Previous
                        IconButton(
                          icon: const Icon(Icons.navigate_before,
                              color: Colors.white),
                          onPressed: _currentMoveIndex > 0
                              ? () => setState(
                                  () => _currentMoveIndex--)
                              : null,
                        ),
                        // Play/Pause
                        GlassButton(
                          label: _isPlaying ? 'Pause' : 'Play',
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: totalMoves > 0
                              ? () => setState(() =>
                                  _isPlaying = !_isPlaying)
                              : null,
                          size: GlassButtonSize.small,
                          variant: GlassButtonVariant.filled,
                        ),
                        // Next
                        IconButton(
                          icon: const Icon(Icons.navigate_next,
                              color: Colors.white),
                          onPressed:
                              _currentMoveIndex < totalMoves - 1
                                  ? () => setState(
                                      () => _currentMoveIndex++)
                                  : null,
                        ),
                        // Last move
                        IconButton(
                          icon: const Icon(Icons.skip_next,
                              color: Colors.white),
                          onPressed: totalMoves > 0
                              ? () => setState(() =>
                                  _currentMoveIndex =
                                      totalMoves - 1)
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // Progress bar
                  if (totalMoves > 0) ...[
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor:
                            Colors.white.withOpacity(0.15),
                        thumbColor: AppColors.accent,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: _currentMoveIndex.toDouble(),
                        min: 0,
                        max: (totalMoves - 1).toDouble().clamp(0, double.infinity),
                        onChanged: (v) =>
                            setState(() => _currentMoveIndex = v.round()),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _describeMoveAt(List moves, int index) {
    if (index < 0 || index >= moves.length) return '';
    final move = moves[index] as Map<String, dynamic>;
    final playerId = move['player_id'] as String? ?? 'Unknown';
    final seq = move['sequence_number'] ?? index + 1;
    return 'Seq #$seq by ${playerId.substring(0, 8)}…';
  }

  String _displayName(String gameType) {
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
        return gameType;
    }
  }
}
