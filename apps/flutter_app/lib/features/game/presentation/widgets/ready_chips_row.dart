import 'package:flutter/material.dart';

import 'ready_chip.dart';

class ReadyChipData {
  final String playerId;
  final String name;
  final bool isBot;
  final bool isReady;

  const ReadyChipData({
    required this.playerId,
    required this.name,
    required this.isBot,
    required this.isReady,
  });
}

class ReadyChipsRow extends StatelessWidget {
  final List<ReadyChipData> players;
  final double spacing;

  const ReadyChipsRow({
    super.key,
    required this.players,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in players)
          ReadyChip(
            key: ValueKey('ready-chip-${p.playerId}'),
            playerName: p.name,
            isReady: p.isReady,
            isBot: p.isBot,
          ),
      ],
    );
  }
}
