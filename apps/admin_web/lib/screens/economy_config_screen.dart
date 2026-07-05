import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/admin_api.dart';
import '../theme.dart';

/// Integer knobs (>= 0) with a friendly label.
const _intFields = <(String, String)>[
  ('game_end_coins_win', 'Coins — win'),
  ('game_end_coins_loss', 'Coins — loss'),
  ('game_end_xp_win', 'XP — win'),
  ('game_end_xp_loss', 'XP — loss'),
  ('first_win_of_day_bonus', 'First-win-of-day bonus'),
  ('daily_coin_earn_cap', 'Daily coin earn cap'),
  ('welcome_gem_grant', 'Welcome gem grant'),
  ('active_tournament_cap', 'Active tournament cap (>= 1)'),
];

class EconomyConfigScreen extends ConsumerWidget {
  const EconomyConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(economyConfigProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (cfg) => _Editor(cfg: cfg),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.cfg});
  final Map<String, dynamic> cfg;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ints;
  late final TextEditingController _rake;
  late final Map<String, TextEditingController> _multipliers;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ints = {
      for (final (key, _) in _intFields)
        key: TextEditingController(text: '${widget.cfg[key] ?? 0}'),
    };
    _rake = TextEditingController(
        text: '${widget.cfg['rake_percent_default'] ?? 10}');
    final tiers = Map<String, dynamic>.from(
        widget.cfg['tier_earn_multiplier'] as Map? ?? const {});
    _multipliers = {
      for (final entry in tiers.entries)
        entry.key: TextEditingController(text: '${entry.value}'),
    };
  }

  @override
  void dispose() {
    for (final c in _ints.values) {
      c.dispose();
    }
    for (final c in _multipliers.values) {
      c.dispose();
    }
    _rake.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final patch = <String, dynamic>{
        for (final e in _ints.entries) e.key: int.parse(e.value.text),
        'rake_percent_default': double.parse(_rake.text),
        'tier_earn_multiplier': {
          for (final e in _multipliers.entries)
            e.key: double.parse(e.value.text),
        },
      };
      await ref.read(adminApiProvider).updateEconomyConfig(patch);
      ref.invalidate(economyConfigProvider);
      messenger.showSnackBar(
          const SnackBar(content: Text('Economy config saved.')));
    } on AdminApiException catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(
        children: [
          Row(
            children: [
              Text('Economy config',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('updated ${widget.cfg['updated_at'] ?? ''}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Changes take effect immediately — no deploy.',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final (key, label) in _intFields)
                      SizedBox(
                        width: 220,
                        child: TextFormField(
                          controller: _ints[key],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: label),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null) return 'Number';
                            if (key == 'active_tournament_cap' && n < 1) {
                              return '>= 1';
                            }
                            if (n < 0) return '>= 0';
                            return null;
                          },
                        ),
                      ),
                    SizedBox(
                      width: 220,
                      child: TextFormField(
                        controller: _rake,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Default rake %'),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null) return 'Number';
                          if (n < 0 || n > 100) return '0–100';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Tier earn multipliers',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final tier in _multipliers.keys)
                      SizedBox(
                        width: 160,
                        child: TextFormField(
                          controller: _multipliers[tier],
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration:
                              InputDecoration(labelText: '${tier[0].toUpperCase()}${tier.substring(1)} ×'),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n < 0) return '>= 0';
                            return null;
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save config'),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
