import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/felt_background.dart';
import '../../../../shared/widgets/glass_app_bar.dart';
import '../../data/tournament_models.dart';
import '../../providers/tournament_providers.dart';
import '../widgets/tournament_card.dart';

class TournamentsScreen extends ConsumerStatefulWidget {
  const TournamentsScreen({super.key});

  @override
  ConsumerState<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends ConsumerState<TournamentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: 'Tournaments',
        ),
        body: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 8),
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
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.4),
                  ),
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
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Live'),
                  Tab(text: 'My'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _UpcomingTab(),
                  _LiveTab(),
                  _MyTournamentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(upcomingTournamentsProvider(null));

    return tournaments.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppColors.textFeltMuted)),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(upcomingTournamentsProvider),
        child: _buildList(context, list, 'No upcoming tournaments',
            showTodaySchedule: true),
      ),
    );
  }
}

class _LiveTab extends ConsumerWidget {
  const _LiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(liveTournamentsProvider(null));

    return tournaments.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppColors.textFeltMuted)),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(liveTournamentsProvider),
        child: _buildList(context, list, 'No live tournaments'),
      ),
    );
  }
}

class _MyTournamentsTab extends ConsumerWidget {
  const _MyTournamentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(myTournamentsProvider);

    return tournaments.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppColors.textFeltMuted)),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTournamentsProvider),
        child: _buildMyList(
          context,
          list,
          ref.watch(currentUserProvider)?.id,
        ),
      ),
    );
  }
}

/// History list: same cards as the other tabs, plus MY outcome per
/// completed/cancelled tournament — placement and net coins/gems (#187).
/// Computed entirely from data the card already has (final_standings,
/// prize_pool, entry fees, status); game rewards are deliberately excluded.
Widget _buildMyList(
  BuildContext context,
  List<Tournament> tournaments,
  String? userId,
) {
  if (tournaments.isEmpty) {
    return _buildList(context, tournaments, "You haven't joined any tournaments");
  }
  return ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    itemCount: tournaments.length,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final tournament = tournaments[index];
      final (text, color) = _myOutcome(tournament, userId);
      return TournamentCard(
        tournament: tournament,
        outcomeText: text,
        outcomeColor: color,
        onTap: () => context.push(AppRoutes.tournamentPath(tournament.id)),
      );
    },
  );
}

(String?, Color?) _myOutcome(Tournament t, String? userId) {
  if (userId == null) return (null, null);
  if (t.status == TournamentStatus.cancelled) {
    final paid = t.entryFeeCoins > 0 || t.entryFeeGems > 0;
    return (paid ? 'Cancelled — fee refunded' : 'Cancelled', AppColors.textMuted);
  }
  if (t.status != TournamentStatus.completed) return (null, null);
  final place = t.placeFor(userId);
  if (place == null) return ('Played', AppColors.textMuted);
  final prize = t.prizeForPlace(place);
  final netCoins = (prize?.coins ?? 0) - t.entryFeeCoins;
  final netGems = (prize?.gems ?? 0) - t.entryFeeGems;
  final placeLabel = switch (place) {
    1 => '🏆 1st',
    2 => '🥈 2nd',
    3 => '🥉 3rd',
    _ => '${place}th',
  };
  final parts = <String>[];
  if (netCoins != 0 || netGems == 0) {
    parts.add('${netCoins > 0 ? '+' : ''}$netCoins coins');
  }
  if (netGems != 0) parts.add('${netGems > 0 ? '+' : ''}$netGems gems');
  final positive = netCoins > 0 || netGems > 0;
  final negative = !positive && (netCoins < 0 || netGems < 0);
  return (
    '$placeLabel · ${parts.join(' ')}',
    positive
        ? AppColors.success
        : negative
            ? AppColors.danger
            : AppColors.textMuted,
  );
}

Widget _buildList(
  BuildContext context,
  List<Tournament> tournaments,
  String emptyMessage, {
  bool showTodaySchedule = false,
}) {
  // Today's schedule strip (#259/Epic #250 Phase 2): the day's clock events
  // at a glance. Only upcoming registrations starting today, by start time.
  final now = DateTime.now();
  final today = !showTodaySchedule
      ? const <Tournament>[]
      : (tournaments
          .where((t) =>
              t.status == TournamentStatus.registration &&
              t.startTime.toLocal().year == now.year &&
              t.startTime.toLocal().month == now.month &&
              t.startTime.toLocal().day == now.day)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime)));
  if (tournaments.isEmpty) {
    // Scrollable even when empty so pull-to-refresh still works.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(Icons.emoji_events_outlined,
              size: 48, color: AppColors.textFeltMuted),
          const SizedBox(height: 12),
          Text(
            emptyMessage,
            style: const TextStyle(
              color: AppColors.textFeltMuted,
              fontSize: 15,
            ),
          ),
          ],
        ),
      ],
    );
  }

  final headerCount = today.isEmpty ? 0 : 1;
  return ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    itemCount: tournaments.length + headerCount,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      if (headerCount == 1 && index == 0) {
        return _TodayScheduleStrip(items: today);
      }
      final tournament = tournaments[index - headerCount];
      return TournamentCard(
        tournament: tournament,
        onTap: () => context.push(AppRoutes.tournamentPath(tournament.id)),
      );
    },
  );
}

/// Horizontal at-a-glance strip of today's scheduled events (#259).
class _TodayScheduleStrip extends StatelessWidget {
  const _TodayScheduleStrip({required this.items});
  final List<Tournament> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            "TODAY'S SCHEDULE",
            style: TextStyle(
              color: AppColors.textFeltMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in items) ...[
                GestureDetector(
                  onTap: () => context.push(AppRoutes.tournamentPath(t.id)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t.startTime.toLocal().hour.toString().padLeft(2, '0')}:'
                          '${t.startTime.toLocal().minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.name,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          t.isFull
                              ? 'Full'
                              : '${t.currentParticipants}/${t.maxParticipants} joined',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
