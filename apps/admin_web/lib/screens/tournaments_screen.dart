import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import '../services/admin_api.dart';
import '../theme.dart';

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({super.key});

  static final _dateFmt = DateFormat('MMM d, HH:mm');

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String okMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(tournamentsProvider);
      messenger.showSnackBar(SnackBar(content: Text(okMessage)));
    } on AdminApiException catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tournamentsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tournaments',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(tournamentsProvider),
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => context.go('/tournaments/new'),
                icon: const Icon(Icons.add),
                label: const Text('New tournament'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('No tournaments yet.'))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _TournamentTile(
                        t: rows[i],
                        dateFmt: _dateFmt,
                        onCancel: () => _run(
                          context,
                          ref,
                          () => ref
                              .read(adminApiProvider)
                              .cancelTournament(rows[i]['id'] as String),
                          'Tournament cancelled & entries refunded.',
                        ),
                        onForceStart: () => _run(
                          context,
                          ref,
                          () => ref
                              .read(adminApiProvider)
                              .forceStartTournament(rows[i]['id'] as String),
                          'Force-start triggered.',
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentTile extends StatelessWidget {
  const _TournamentTile({
    required this.t,
    required this.dateFmt,
    required this.onCancel,
    required this.onForceStart,
  });

  final Map<String, dynamic> t;
  final DateFormat dateFmt;
  final VoidCallback onCancel;
  final VoidCallback onForceStart;

  Color _statusColor(String status) => switch (status) {
        'registration' => AppColors.gold,
        'in_progress' => AppColors.success,
        'completed' => AppColors.textMuted,
        'cancelled' => AppColors.danger,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final status = (t['status'] ?? '') as String;
    final start = DateTime.tryParse((t['start_time'] ?? '') as String);
    final terminal = status == 'completed' || status == 'cancelled';
    final canStart = status == 'registration' || status == 'starting';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: _statusColor(status), shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(t['name'] as String? ?? '(unnamed)',
                            style:
                                Theme.of(context).textTheme.titleMedium),
                      ),
                      if (t['is_official'] == true) ...[
                        const SizedBox(width: 8),
                        const _Chip('OFFICIAL', AppColors.gold),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t['game_type']} · ${t['format']} · '
                    '${t['current_participants']}/${t['max_participants']} players · '
                    '${status.toUpperCase()}'
                    '${start != null ? ' · ${dateFmt.format(start.toLocal())}' : ''}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (canStart)
              TextButton.icon(
                onPressed: onForceStart,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Force start'),
              ),
            if (!terminal)
              TextButton.icon(
                onPressed: () => _confirmCancel(context),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel tournament?'),
        content: Text(
            'This cancels "${t['name']}" and refunds all entry fees. This '
            'cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel & refund'),
          ),
        ],
      ),
    );
    if (ok == true) onCancel();
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
