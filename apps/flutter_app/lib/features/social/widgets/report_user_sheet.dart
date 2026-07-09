import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../friends/data/discovery_repository.dart';

/// Report a player. Writes to `user_reports`; review happens in the admin
/// console's moderation queue.
class ReportUserSheet extends ConsumerStatefulWidget {
  final String targetId;
  final String targetName;

  /// One of: dm, room_chat, party, voice, profile, game.
  final String reportContext;
  final String? contextId;

  const ReportUserSheet({
    super.key,
    required this.targetId,
    required this.targetName,
    required this.reportContext,
    this.contextId,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetId,
    required String targetName,
    required String reportContext,
    String? contextId,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReportUserSheet(
        targetId: targetId,
        targetName: targetName,
        reportContext: reportContext,
        contextId: contextId,
      ),
    );
  }

  @override
  ConsumerState<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends ConsumerState<ReportUserSheet> {
  static const _reasons = {
    'harassment': 'Harassment or abuse',
    'spam': 'Spam',
    'cheating': 'Cheating',
    'inappropriate_name': 'Inappropriate name',
    'other': 'Something else',
  };

  String? _reason;
  final _detail = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(discoveryRepositoryProvider).reportUser(
            targetId: widget.targetId,
            context: widget.reportContext,
            contextId: widget.contextId,
            reason: reason,
            detail: _detail.text,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks — our team will review this report.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't submit the report")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.feltDark.withOpacity(0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report ${widget.targetName}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnFelt,
                ),
              ),
              const SizedBox(height: 8),
              ..._reasons.entries.map(
                (e) => RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    e.value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textOnFelt,
                    ),
                  ),
                  value: e.key,
                  groupValue: _reason,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setState(() => _reason = v),
                ),
              ),
              TextField(
                controller: _detail,
                maxLength: 500,
                maxLines: 2,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textOnFelt),
                decoration: const InputDecoration(
                  hintText: 'Anything else we should know? (optional)',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed:
                        (_reason == null || _submitting) ? null : _submit,
                    child: const Text('Submit report'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
