import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Recurrence template controls (#253, Epic #250 Phase 1).
///
/// Templates drive the self-operating tournament calendar: daily/weekly
/// clock events are materialized by tournament-tick inside their lead
/// window; sit&go templates keep exactly one open instance alive. Edits
/// apply to FUTURE instances only.
final templatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminApiProvider).listTemplates();
});

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Tournaments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(templatesProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New template'),
        onPressed: () => _openEditor(context, ref),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (rows) => rows.isEmpty
            ? const Center(
                child: Text(
                    'No templates yet.\nCreate one and the scheduler does the rest.',
                    textAlign: TextAlign.center),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _TemplateTile(template: rows[i]),
              ),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template});
  final Map<String, dynamic> template;

  String get _schedule {
    final kind = template['schedule_kind'] as String;
    if (kind == 'sitgo') return 'Sit & Go — always one open table';
    final time = template['start_hhmm'] ?? '--:--';
    final off = (template['tz_offset_min'] as num?)?.toInt() ?? 0;
    final tz = off == 330 ? 'IST' : 'UTC${off >= 0 ? '+' : ''}${off ~/ 60}';
    if (kind == 'weekly') {
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return 'Weekly ${days[(template['weekday'] as num?)?.toInt() ?? 0]} $time $tz';
    }
    return 'Daily $time $tz';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = template['active'] == true;
    final latest = template['latest_instance'] as Map<String, dynamic>?;
    final lastError = template['last_error'] as String?;

    return Card(
      child: ListTile(
        onTap: () => _openEditor(context, ref, existing: template),
        title: Row(
          children: [
            Expanded(
              child: Text(template['name'] as String? ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (!active)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('PAUSED'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${template['game_type']} · $_schedule · '
                '${template['min_participants']}-${template['max_participants']} players · '
                'entry ${template['entry_fee_coins']}c'
                '${(template['entry_fee_gems'] as num? ?? 0) > 0 ? ' + ${template['entry_fee_gems']}g' : ''}'),
            if (latest != null)
              Text(
                'Latest instance: ${latest['status']} '
                '(${latest['current_participants']}/${latest['max_participants']})',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            if (lastError != null)
              Text('⚠ $lastError',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        trailing: Switch(
          value: active,
          onChanged: (v) async {
            try {
              await ref
                  .read(adminApiProvider)
                  .updateTemplate(template['id'] as String, {'active': v});
              ref.invalidate(templatesProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
        ),
      ),
    );
  }
}

Future<void> _openEditor(BuildContext context, WidgetRef ref,
    {Map<String, dynamic>? existing}) async {
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _TemplateEditorDialog(existing: existing),
  );
  if (result == null) return;
  try {
    final api = ref.read(adminApiProvider);
    if (existing == null) {
      await api.createTemplate(result);
    } else {
      await api.updateTemplate(existing['id'] as String, result);
    }
    ref.invalidate(templatesProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.existing?['name'] as String? ?? '');
  late final _time = TextEditingController(
      text: widget.existing?['start_hhmm'] as String? ?? '21:00');
  late final _lead = TextEditingController(
      text: '${widget.existing?['registration_lead_minutes'] ?? 180}');
  late final _minP =
      TextEditingController(text: '${widget.existing?['min_participants'] ?? 4}');
  late final _maxP = TextEditingController(
      text: '${widget.existing?['max_participants'] ?? 16}');
  late final _fee = TextEditingController(
      text: '${widget.existing?['entry_fee_coins'] ?? 0}');
  late final _checkIn = TextEditingController(
      text: '${widget.existing?['check_in_minutes'] ?? 0}');

  late String _game = widget.existing?['game_type'] as String? ?? 'oh_hell';
  late String _kind =
      widget.existing?['schedule_kind'] as String? ?? 'daily';
  late int _weekday = (widget.existing?['weekday'] as num?)?.toInt() ?? 0;

  static const _games = ['oh_hell', 'twenty_nine', 'ludo'];
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  bool get _isClock => _kind != 'sitgo';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New template' : 'Edit template'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _game,
                      decoration: const InputDecoration(labelText: 'Game'),
                      items: [
                        for (final g in _games)
                          DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: (v) => setState(() => _game = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _kind,
                      decoration: const InputDecoration(labelText: 'Schedule'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(
                            value: 'sitgo', child: Text('Sit & Go')),
                      ],
                      onChanged: (v) => setState(() => _kind = v!),
                    ),
                  ),
                ]),
                if (_isClock) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    if (_kind == 'weekly') ...[
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _weekday,
                          decoration:
                              const InputDecoration(labelText: 'Weekday'),
                          items: [
                            for (var i = 0; i < 7; i++)
                              DropdownMenuItem(
                                  value: i, child: Text(_days[i])),
                          ],
                          onChanged: (v) => setState(() => _weekday = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextFormField(
                        controller: _time,
                        decoration: const InputDecoration(
                            labelText: 'Start (HH:MM IST)'),
                        validator: (v) =>
                            RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                                    .hasMatch(v ?? '')
                                ? null
                                : 'HH:MM',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lead,
                        decoration: const InputDecoration(
                            labelText: 'Open reg. (min before)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minP,
                      decoration:
                          const InputDecoration(labelText: 'Min players'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxP,
                      decoration:
                          const InputDecoration(labelText: 'Max players'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fee,
                      decoration:
                          const InputDecoration(labelText: 'Entry (coins)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _checkIn,
                      decoration: const InputDecoration(
                          labelText: 'Check-in (min, 0=off)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'name': _name.text.trim(),
              'game_type': _game,
              'schedule_kind': _kind,
              if (_isClock) 'start_hhmm': _time.text.trim(),
              if (_kind == 'weekly') 'weekday': _weekday,
              if (_isClock)
                'registration_lead_minutes':
                    int.tryParse(_lead.text) ?? 180,
              'tz_offset_min': 330,
              'min_participants': int.tryParse(_minP.text) ?? 4,
              'max_participants': int.tryParse(_maxP.text) ?? 16,
              'entry_fee_coins': int.tryParse(_fee.text) ?? 0,
              'check_in_minutes': int.tryParse(_checkIn.text) ?? 0,
            });
          },
          child: Text(widget.existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
