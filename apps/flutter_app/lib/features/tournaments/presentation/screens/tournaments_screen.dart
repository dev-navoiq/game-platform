import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      data: (list) => _buildList(context, list, 'No upcoming tournaments'),
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
      data: (list) => _buildList(context, list, 'No live tournaments'),
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
      data: (list) =>
          _buildList(context, list, 'You haven\'t joined any tournaments'),
    );
  }
}

Widget _buildList(
  BuildContext context,
  List<Tournament> tournaments,
  String emptyMessage,
) {
  if (tournaments.isEmpty) {
    return Center(
      child: Column(
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
    );
  }

  return ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    itemCount: tournaments.length,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final tournament = tournaments[index];
      return TournamentCard(
        tournament: tournament,
        onTap: () => context.push(AppRoutes.tournamentPath(tournament.id)),
      );
    },
  );
}
