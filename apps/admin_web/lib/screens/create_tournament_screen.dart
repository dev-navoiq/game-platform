import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../services/admin_api.dart';
import '../theme.dart';

// Server allow-lists (admin-create-tournament rejects anything else): only
// games with server-side rules + outcome adapters, per match shape.
const _games1v1 = ['twenty_nine', 'oh_hell', 'ludo'];
const _games2v2 = ['twenty_nine', 'bridge'];
// Server-supported start formats (bracket generation exists for these).
const _formats = ['single_elimination', 'round_robin', 'swiss'];
const _tiers = ['free', 'pro', 'max'];
const _socialModes = ['focus', 'chat_only', 'silent', 'full'];

class _PrizeRow {
  _PrizeRow(this.place);
  int place;
  final coins = TextEditingController();
  final gems = TextEditingController();
  final gemCup = TextEditingController(); // platform-seeded gem bonus
}

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends ConsumerState<CreateTournamentScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _minP = TextEditingController(text: '4');
  final _maxP = TextEditingController(text: '8');
  final _feeCoins = TextEditingController(text: '0');
  final _feeGems = TextEditingController(text: '0');

  String _gameType = _games1v1.first;
  String _format = _formats.first;
  String _tier = _tiers.first;
  String _socialMode = _socialModes.first;
  int _teamSize = 1;
  bool _allowSoloPairing = false;

  List<String> get _gameChoices => _teamSize == 2 ? _games2v2 : _games1v1;
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  final List<_PrizeRow> _prizes = [_PrizeRow(1), _PrizeRow(2)];
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _minP, _maxP, _feeCoins, _feeGems]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null) return;
    setState(() => _startTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  Map<String, dynamic> _buildPayload() {
    final prizePool = <Map<String, dynamic>>[];
    final gemCup = <String, int>{};
    for (final p in _prizes) {
      final coins = int.tryParse(p.coins.text) ?? 0;
      final gems = int.tryParse(p.gems.text) ?? 0;
      final cup = int.tryParse(p.gemCup.text) ?? 0;
      if (coins > 0 || gems > 0) {
        prizePool.add({
          'place': p.place,
          if (coins > 0) 'coins': coins,
          if (gems > 0) 'gems': gems,
        });
      }
      if (cup > 0) gemCup[p.place.toString()] = cup;
    }

    return {
      'name': _name.text.trim(),
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      'game_type': _gameType,
      'format': _format,
      'start_time': _startTime.toUtc().toIso8601String(),
      'min_participants': int.parse(_minP.text),
      'max_participants': int.parse(_maxP.text),
      'entry_fee_coins': int.tryParse(_feeCoins.text) ?? 0,
      'entry_fee_gems': int.tryParse(_feeGems.text) ?? 0,
      'prize_pool': prizePool,
      'min_subscription_tier': _tier,
      'room_social_mode': _socialMode,
      'team_size': _teamSize,
      if (_teamSize == 2 && _gameType != 'bridge')
        'allow_solo_pairing': _allowSoloPairing,
      if (gemCup.isNotEmpty) 'settings': {'gem_cup': gemCup},
    };
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminApiProvider).createTournament(_buildPayload());
      ref.invalidate(tournamentsProvider);
      if (mounted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Tournament created.')));
        context.go('/tournaments');
      }
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: ListView(
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: () => context.go('/tournaments'),
                    icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 8),
                Text('New tournament',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _description,
                    decoration:
                        const InputDecoration(labelText: 'Description (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _dropdown('Mode', _teamSize == 2 ? '2v2 teams' : '1v1',
                              const ['1v1', '2v2 teams'], (v) => setState(() {
                                _teamSize = v == '2v2 teams' ? 2 : 1;
                                if (!_gameChoices.contains(_gameType)) {
                                  _gameType = _gameChoices.first;
                                }
                              }))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: _dropdown('Game', _gameType, _gameChoices,
                              (v) => setState(() => _gameType = v))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: _dropdown('Format', _format, _formats,
                              (v) => setState(() => _format = v))),
                    ],
                  ),
                  if (_teamSize == 2 && _gameType != 'bridge') ...[
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow solo entries (paired at start)'),
                      value: _allowSoloPairing,
                      onChanged: (v) => setState(() => _allowSoloPairing = v),
                    ),
                  ],
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _pickStart,
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'Start time (local)'),
                      child: Text(_startTime.toString().substring(0, 16)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _numField(_minP, 'Min players',
                              min: 2, requiredField: true)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: _numField(_maxP, 'Max players',
                              min: 2, requiredField: true)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _numField(_feeCoins, 'Entry fee (coins)')),
                      const SizedBox(width: 14),
                      Expanded(child: _numField(_feeGems, 'Entry fee (gems)')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _dropdown('Min tier', _tier, _tiers,
                              (v) => setState(() => _tier = v))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: _dropdown('Room mode', _socialMode,
                              _socialModes,
                              (v) => setState(() => _socialMode = v))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Prizes',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      const Text('(coins / gems paid from pool · gem-cup = platform bonus)',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._prizes.map(_prizeRow),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() =>
                          _prizes.add(_PrizeRow(_prizes.length + 1))),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add place'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create tournament'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prizeRow(_PrizeRow p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text('#${p.place}',
                  style: Theme.of(context).textTheme.titleMedium)),
          Expanded(child: _numFieldC(p.coins, 'Coins')),
          const SizedBox(width: 10),
          Expanded(child: _numFieldC(p.gems, 'Gems')),
          const SizedBox(width: 10),
          Expanded(child: _numFieldC(p.gemCup, 'Gem cup')),
          IconButton(
            tooltip: 'Remove',
            onPressed: _prizes.length <= 1
                ? null
                : () => setState(() {
                      _prizes.remove(p);
                      for (var i = 0; i < _prizes.length; i++) {
                        _prizes[i].place = i + 1;
                      }
                    }),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
      ],
      onChanged: (v) => onChanged(v!),
    );
  }

  Widget _numField(TextEditingController c, String label,
      {int? min, bool requiredField = false}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (!requiredField && (v == null || v.isEmpty)) return null;
        final n = int.tryParse(v ?? '');
        if (n == null) return 'Number';
        if (min != null && n < min) return '>= $min';
        return null;
      },
    );
  }

  Widget _numFieldC(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }
}
