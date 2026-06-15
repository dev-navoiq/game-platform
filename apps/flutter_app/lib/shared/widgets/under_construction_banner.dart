import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// Amber ribbon shown on screens that ship UI but aren't yet wired to a
/// real backend. Beta testers see at a glance that what's below isn't
/// production behaviour — buttons may not do anything, numbers may be
/// hardcoded, etc.
///
/// Drop into the top of any WIP screen body. Keep messages short; the
/// space below it is meant for the half-built feature.
class UnderConstructionBanner extends StatelessWidget {
  final String message;

  const UnderConstructionBanner({
    super.key,
    this.message = 'Under construction — not yet functional. Coming in a future build.',
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFE9A23B);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: amber.withOpacity(0.18),
        border: Border.all(color: amber.withOpacity(0.55), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction, size: 18, color: amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
