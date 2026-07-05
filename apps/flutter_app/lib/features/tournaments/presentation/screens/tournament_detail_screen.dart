import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/felt_background.dart';
import '../../../../shared/widgets/glass_app_bar.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../data/tournament_models.dart';
import '../../providers/tournament_providers.dart';
import '../widgets/bracket_view.dart';
import '../widgets/standings_table.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState
    extends ConsumerState<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tournamentAsync =
        ref.watch(tournamentDetailProvider(widget.tournamentId));

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: 'Tournament',
        ),
        body: tournamentAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.textFeltMuted)),
          ),
          data: (tournament) {
            if (tournament == null) {
              return const Center(
                child: Text('Tournament not found',
                    style: TextStyle(color: AppColors.textFeltMuted)),
              );
            }
            return _buildContent(tournament);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Tournament tournament) {
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Column(
      children: [
        SizedBox(
            height: MediaQuery.of(context).padding.top + kToolbarHeight + 8),

        // Tournament info header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TournamentHeader(tournament: tournament),
        ),

        const SizedBox(height: 12),

        // Registration button
        if (tournament.isRegistrationOpen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRegistrationButton(tournament),
          ),

        const SizedBox(height: 12),

        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textFeltMuted,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Bracket'),
              Tab(text: 'Participants'),
              Tab(text: 'Chat'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _BracketTab(
                tournamentId: widget.tournamentId,
                tournament: tournament,
                currentUserId: currentUserId,
              ),
              _ParticipantsTab(
                tournamentId: widget.tournamentId,
                tournament: tournament,
                currentUserId: currentUserId,
              ),
              _ChatTab(
                tournamentId: widget.tournamentId,
                currentUserId: currentUserId,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationButton(Tournament tournament) {
    final myParticipation =
        ref.watch(myParticipationProvider(widget.tournamentId));

    return myParticipation.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (participation) {
        if (participation != null) {
          // Already registered — show withdraw
          return GlassButton(
            label: 'Withdraw',
            onPressed: _isRegistering ? null : () => _unregister(tournament),
            isLoading: _isRegistering,
          );
        }

        // Not registered — show register
        return GlassButton(
          label: tournament.isFree
              ? 'Register (Free)'
              : 'Register (${_formatEntryFee(tournament)})',
          onPressed: _isRegistering ? null : () => _register(tournament),
          isLoading: _isRegistering,
          icon: const Icon(Icons.how_to_reg, size: 18),
        );
      },
    );
  }

  Future<void> _register(Tournament tournament) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _isRegistering = true);

    final repo = ref.read(tournamentRepositoryProvider);
    final result = await repo.register(widget.tournamentId, userId);

    setState(() => _isRegistering = false);

    if (!mounted) return;

    final message = switch (result) {
      TournamentRegistrationResult.success => 'Registered successfully!',
      TournamentRegistrationResult.alreadyRegistered => 'Already registered',
      TournamentRegistrationResult.tournamentFull => 'Tournament is full',
      TournamentRegistrationResult.insufficientFunds =>
        'Insufficient funds',
      TournamentRegistrationResult.registrationClosed =>
        'Registration is closed',
      TournamentRegistrationResult.tierRequired =>
        'Subscription required',
      _ => 'Registration failed',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result == TournamentRegistrationResult.success
            ? AppColors.success
            : AppColors.danger,
      ),
    );

    if (result == TournamentRegistrationResult.success) {
      // Refresh data
      ref.invalidate(tournamentDetailProvider(widget.tournamentId));
      ref.invalidate(myParticipationProvider(widget.tournamentId));
      ref.invalidate(tournamentParticipantsProvider(widget.tournamentId));
      ref.invalidate(myTournamentsProvider);
      ref.invalidate(userProfileProvider); // entry fee changed the balance
    }
  }

  Future<void> _unregister(Tournament tournament) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _isRegistering = true);

    final repo = ref.read(tournamentRepositoryProvider);
    final success = await repo.unregister(widget.tournamentId, userId);

    setState(() => _isRegistering = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Withdrawn successfully' : 'Could not withdraw'),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ),
    );

    if (success) {
      ref.invalidate(tournamentDetailProvider(widget.tournamentId));
      ref.invalidate(myParticipationProvider(widget.tournamentId));
      ref.invalidate(tournamentParticipantsProvider(widget.tournamentId));
      ref.invalidate(myTournamentsProvider);
      ref.invalidate(userProfileProvider); // refund changed the balance
    }
  }

  String _formatEntryFee(Tournament tournament) {
    final parts = <String>[];
    if (tournament.entryFeeCoins > 0) {
      parts.add('${tournament.entryFeeCoins} coins');
    }
    if (tournament.entryFeeGems > 0) {
      parts.add('${tournament.entryFeeGems} gems');
    }
    return parts.join(' + ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _TournamentHeader extends StatelessWidget {
  final Tournament tournament;

  const _TournamentHeader({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: GlassTokens.radiusMedium,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (tournament.isOfficial)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OFFICIAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  tournament.name,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (tournament.description != null) ...[
            const SizedBox(height: 6),
            Text(
              tournament.description!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _StatItem(
                icon: Icons.account_tree_outlined,
                label: tournament.format.displayName,
              ),
              const SizedBox(width: 16),
              _StatItem(
                icon: Icons.people_outline,
                label:
                    '${tournament.currentParticipants}/${tournament.maxParticipants}',
              ),
              const SizedBox(width: 16),
              _StatItem(
                icon: Icons.shield_outlined,
                label: 'Room: ${tournament.roomSocialMode}',
              ),
            ],
          ),
          // Prizes
          if (tournament.prizes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Prizes',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tournament.prizes
                  .map((p) => _PrizeChip(prize: p))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _PrizeChip extends StatelessWidget {
  final TournamentPrize prize;

  const _PrizeChip({required this.prize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 13, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            '${prize.placeLabel}: ${_formatReward(prize)}',
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatReward(TournamentPrize prize) {
    final parts = <String>[];
    if (prize.coins > 0) parts.add('${prize.coins}c');
    if (prize.gems > 0) parts.add('${prize.gems}g');
    if (prize.skinId != null) parts.add('Skin');
    if (prize.title != null) parts.add('"${prize.title}"');
    return parts.isEmpty ? 'TBD' : parts.join(' + ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs
// ─────────────────────────────────────────────────────────────────────────────

class _BracketTab extends ConsumerWidget {
  final String tournamentId;
  final Tournament tournament;
  final String? currentUserId;

  const _BracketTab({
    required this.tournamentId,
    required this.tournament,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use realtime stream for live tournaments, snapshot otherwise
    if (tournament.isLive) {
      final bracketStream =
          ref.watch(tournamentBracketStreamProvider(tournamentId));
      return bracketStream.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.textFeltMuted)),
        ),
        data: (matches) => _buildBracketContent(context, ref, matches),
      );
    }

    final bracket = ref.watch(tournamentBracketProvider(tournamentId));
    return bracket.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppColors.textFeltMuted)),
      ),
      data: (matches) => _buildBracketContent(context, ref, matches),
    );
  }

  Widget _buildBracketContent(
    BuildContext context,
    WidgetRef ref,
    List<TournamentMatch> matches,
  ) {
    if (matches.isEmpty) {
      return const Center(
        child: Text(
          'Bracket will appear once the tournament starts',
          style: TextStyle(color: AppColors.textFeltMuted, fontSize: 14),
        ),
      );
    }

    // For round robin / swiss, show standings + match list
    if (tournament.format == TournamentFormat.roundRobin ||
        tournament.format == TournamentFormat.swiss) {
      final participants =
          ref.watch(tournamentParticipantsProvider(tournamentId));
      return participants.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pList) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StandingsTable(
                  participants: pList,
                  currentUserId: currentUserId,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Matches',
                  style: TextStyle(
                    color: AppColors.textOnFelt,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...matches.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MatchCard(
                        match: m,
                        currentUserId: currentUserId,
                      ),
                    )),
              ],
            ),
          );
        },
      );
    }

    // Elimination brackets
    return SingleChildScrollView(
      child: BracketView(
        matches: matches,
        currentUserId: currentUserId,
      ),
    );
  }
}

class _ParticipantsTab extends ConsumerWidget {
  final String tournamentId;
  final Tournament tournament;
  final String? currentUserId;

  const _ParticipantsTab({
    required this.tournamentId,
    required this.tournament,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants =
        ref.watch(tournamentParticipantsProvider(tournamentId));

    return participants.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppColors.textFeltMuted)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No participants yet',
              style: TextStyle(color: AppColors.textFeltMuted),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final p = list[index];
            final isMe = p.userId == currentUserId;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.accent.withOpacity(0.12)
                    : Colors.white.withOpacity(0.06),
                borderRadius:
                    BorderRadius.circular(GlassTokens.radiusSmall),
                border: isMe
                    ? Border.all(
                        color: AppColors.accent.withOpacity(0.3))
                    : null,
              ),
              child: Row(
                children: [
                  // Seed
                  if (p.seed != null)
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${p.seed}',
                        style: TextStyle(
                          color: AppColors.textFeltMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  // Avatar placeholder
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    child: Text(
                      (p.username ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textOnFelt,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.username ?? 'Player',
                      style: TextStyle(
                        color: AppColors.textOnFelt,
                        fontWeight:
                            isMe ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Status badge
                  _StatusBadge(status: p.status),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ParticipantStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ParticipantStatus.registered => ('Registered', AppColors.textFeltMuted),
      ParticipantStatus.checkedIn => ('Ready', Colors.blue),
      ParticipantStatus.active => ('Playing', AppColors.accent),
      ParticipantStatus.eliminated => ('Out', AppColors.danger),
      ParticipantStatus.winner => ('Winner', AppColors.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChatTab extends ConsumerStatefulWidget {
  final String tournamentId;
  final String? currentUserId;

  const _ChatTab({
    required this.tournamentId,
    this.currentUserId,
  });

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatStream =
        ref.watch(tournamentChatStreamProvider(widget.tournamentId));

    return Column(
      children: [
        Expanded(
          child: chatStream.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.textFeltMuted)),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(color: AppColors.textFeltMuted),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  // Reverse index since we show newest at bottom
                  final msg = messages[messages.length - 1 - index];
                  final isMe = msg.senderId == widget.currentUserId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ChatBubble(message: msg, isMe: isMe),
                  );
                },
              );
            },
          ),
        ),
        // Input bar
        if (widget.currentUserId != null)
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(
                        color: AppColors.textOnFelt, fontSize: 14),
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle:
                          TextStyle(color: AppColors.textFeltMuted),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(Icons.send, color: AppColors.accent),
                  onPressed: _isSending ? null : _send,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.currentUserId == null) return;

    setState(() => _isSending = true);
    _controller.clear();

    final repo = ref.read(tournamentRepositoryProvider);
    await repo.sendChatMessage(
      widget.tournamentId,
      widget.currentUserId!,
      text,
    );

    if (mounted) setState(() => _isSending = false);
  }
}

class _ChatBubble extends StatelessWidget {
  final TournamentChatMessage message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (message.isAnnouncement) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.content,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accent.withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName ?? 'Player',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              message.content,
              style: const TextStyle(
                color: AppColors.textOnFelt,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
