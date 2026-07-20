import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/felt_background.dart';
import '../../../../shared/widgets/glass_app_bar.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../social/widgets/invite_friends_sheet.dart';
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

        // Check-in ready gate (§T6): confirm your spot in the window before
        // start. No-shows are dropped + refunded at start time.
        if (tournament.isCheckInOpen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCheckInBanner(tournament),
          ),

        // Live-match entry: THE way into your tournament game. Without this
        // the room opens server-side but players never find it and the stall
        // sweeper forfeits them (the "tournament never starts" report).
        if (tournament.isLive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildPlayMatchBanner(),
          ),

        // Invite friends — a registered player recruiting their table is
        // the tournament's own acquisition loop.
        if (tournament.isRegistrationOpen)
          TextButton.icon(
            key: const Key('tournament-invite-friends'),
            onPressed: () => InviteFriendsSheet.showForTournament(
              context,
              tournamentId: tournament.id,
              tournamentName: tournament.name,
              gameType: tournament.gameType,
              startTime: tournament.startTime,
            ),
            icon: const Icon(Icons.person_add_alt,
                size: 16, color: AppColors.accent),
            label: const Text(
              'Invite friends',
              style: TextStyle(fontSize: 13, color: AppColors.accent),
            ),
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

  /// Check-in banner: "Check in" button while the window is open, or a
  /// confirmation once done. Shows the live checked-in count as a mini lobby.
  Widget _buildCheckInBanner(Tournament tournament) {
    final my = ref.watch(myParticipationProvider(widget.tournamentId)).valueOrNull;
    if (my == null) return const SizedBox.shrink(); // not registered

    final participants =
        ref.watch(tournamentParticipantsProvider(widget.tournamentId)).valueOrNull ?? const [];
    final checkedIn =
        participants.where((p) => p.status == ParticipantStatus.checkedIn).length;
    final total = participants.length;

    if (my.status == ParticipantStatus.checkedIn) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text(
              'Checked in · $checkedIn/$total ready',
              style: const TextStyle(color: AppColors.success, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GlassButton(
        key: const Key('tournament-check-in'),
        label: 'Check in now · $checkedIn/$total ready',
        icon: const Icon(Icons.how_to_reg, size: 18),
        onPressed: () async {
          final ok = await ref
              .read(tournamentRepositoryProvider)
              .checkIn(widget.tournamentId);
          if (!mounted) return;
          if (ok) {
            ref.invalidate(myParticipationProvider(widget.tournamentId));
            ref.invalidate(tournamentParticipantsProvider(widget.tournamentId));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: AppColors.danger,
                content: Text('Check-in failed — try again')));
          }
        },
      ),
    );
  }

  /// "Your match is live — Play now" banner. Watches the live bracket and
  /// surfaces the current user's active (or ready) match room.
  Widget _buildPlayMatchBanner() {
    final userId = ref.watch(currentUserProvider)?.id;
    if (userId == null) return const SizedBox.shrink();

    final bracket =
        ref.watch(tournamentBracketStreamProvider(widget.tournamentId));
    final myTeamId = ref
        .watch(myParticipationProvider(widget.tournamentId))
        .valueOrNull
        ?.teamId;

    return bracket.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (matches) {
        TournamentMatch? mine;
        for (final m in matches) {
          if ((m.isLive || m.isReady) &&
              m.roomId != null &&
              m.involves(userId, teamId: myTeamId)) {
            mine = m;
            break;
          }
        }
        if (mine == null) return const SizedBox.shrink();
        final roomId = mine.roomId!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: GlassButton(
            key: const Key('tournament-play-match'),
            label: 'Your match is live — Play now',
            icon: const Icon(Icons.sports_esports, size: 18),
            onPressed: () => context.push(AppRoutes.gamePath(roomId)),
          ),
        );
      },
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

    // Team tournaments: pick a mode first (create / join / solo).
    bool createTeam = false;
    String? joinTeamId;
    if (tournament.isTeamTournament) {
      final choice = await _pickTeamMode(tournament);
      if (choice == null) return; // dismissed
      createTeam = choice.createTeam;
      joinTeamId = choice.joinTeamId;
    }

    setState(() => _isRegistering = true);

    final repo = ref.read(tournamentRepositoryProvider);
    final result = await repo.register(
      widget.tournamentId,
      userId,
      createTeam: createTeam,
      joinTeamId: joinTeamId,
    );

    setState(() => _isRegistering = false);

    if (!mounted) return;

    final message = switch (result) {
      TournamentRegistrationResult.success => createTeam
          ? 'Team created — get a partner to join!'
          : 'Registered successfully!',
      TournamentRegistrationResult.alreadyRegistered => 'Already registered',
      TournamentRegistrationResult.tournamentFull => 'Tournament is full',
      TournamentRegistrationResult.insufficientFunds =>
        'Insufficient funds',
      TournamentRegistrationResult.registrationClosed =>
        'Registration is closed',
      TournamentRegistrationResult.tierRequired =>
        'Subscription required',
      TournamentRegistrationResult.teamRequired =>
        'This tournament needs a team — create or join one',
      TournamentRegistrationResult.teamFull => 'That team is already full',
      TournamentRegistrationResult.teamNotFound => 'Team not found',
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
      ref.invalidate(tournamentTeamsProvider(widget.tournamentId));
      ref.invalidate(myTournamentsProvider);
      ref.invalidate(userProfileProvider); // entry fee changed the balance
    }
  }

  /// Bottom sheet: how to enter a 2v2 tournament. Returns null if dismissed.
  Future<({bool createTeam, String? joinTeamId})?> _pickTeamMode(
    Tournament tournament,
  ) async {
    return showModalBottomSheet<({bool createTeam, String? joinTeamId})>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter as a team of 2',
                style: Theme.of(sheetContext).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.group_add, color: AppColors.accent),
                title: const Text('Create a team'),
                subtitle: const Text('Open a team and invite your partner'),
                onTap: () => Navigator.pop(
                    sheetContext, (createTeam: true, joinTeamId: null)),
              ),
              ListTile(
                leading: const Icon(Icons.groups, color: AppColors.accent),
                title: const Text('Join a team'),
                subtitle: const Text('Fill an open seat on an existing team'),
                onTap: () async {
                  final teamId = await _pickOpenTeam(sheetContext);
                  if (teamId != null && sheetContext.mounted) {
                    Navigator.pop(
                        sheetContext, (createTeam: false, joinTeamId: teamId));
                  }
                },
              ),
              if (tournament.allowSoloPairing)
                ListTile(
                  leading:
                      const Icon(Icons.person, color: AppColors.accent),
                  title: const Text('Enter solo'),
                  subtitle: const Text(
                      "We'll pair you with a partner at start time"),
                  onTap: () => Navigator.pop(
                      sheetContext, (createTeam: false, joinTeamId: null)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picker over open (1-member) teams. Returns the chosen team id.
  Future<String?> _pickOpenTeam(BuildContext parentContext) async {
    final teams = await ref
        .read(tournamentRepositoryProvider)
        .getTeams(widget.tournamentId);
    final open = teams.where((t) => t.isOpen).toList();
    if (!parentContext.mounted) return null;
    if (open.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(content: Text('No open teams yet — create one!')),
      );
      return null;
    }
    return showModalBottomSheet<String>(
      context: parentContext,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text('Open teams',
                style: Theme.of(ctx).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            for (final team in open)
              ListTile(
                leading: const Icon(Icons.flag, color: AppColors.accent),
                title: Text(team.displayName),
                subtitle: const Text('1 of 2 seats filled'),
                trailing: const Text('Join'),
                onTap: () => Navigator.pop(ctx, team.id),
              ),
          ],
        ),
      ),
    );
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
