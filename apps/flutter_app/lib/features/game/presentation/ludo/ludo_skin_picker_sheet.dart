import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/monetization_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/colors.dart';
import 'ludo_rider_skin.dart';
import 'ludo_skin_catalog.dart';

/// Bottom sheet for picking the Ludo character. Free skins apply immediately;
/// premium skins show a PRO lock for free-tier users and deep-link to the
/// subscription screen — the picker doubles as an upsell surface.
class LudoSkinPickerSheet extends ConsumerStatefulWidget {
  const LudoSkinPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const LudoSkinPickerSheet(),
    );
  }

  @override
  ConsumerState<LudoSkinPickerSheet> createState() =>
      _LudoSkinPickerSheetState();
}

class _LudoSkinPickerSheetState extends ConsumerState<LudoSkinPickerSheet>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    // Live previews: characters "drive in place" while the sheet is open.
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMicroseconds / 1e6);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedLudoSkinIdProvider);
    final hasPremium = ref.watch(tierBenefitsProvider).exclusiveSkins;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF10131C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose Your Ride',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'How your Ludo tokens look — on this device',
              style:
                  GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            // Flexible + scrollable: with sponsored entries the grid is three
            // rows, which can exceed the default sheet height on small phones.
            Flexible(
              child: GridView.count(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                for (final option in kLudoSkins)
                  _SkinCard(
                    option: option,
                    selected: option.id == selectedId,
                    locked: option.premium && !hasPremium,
                    t: _t,
                    onTap: () => _onTap(option, locked: option.premium && !hasPremium),
                  ),
              ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(LudoSkinOption option, {required bool locked}) {
    if (locked) {
      Navigator.of(context).pop();
      context.push(AppRoutes.subscription);
      return;
    }
    ref.read(selectedLudoSkinIdProvider.notifier).select(option.id);
  }
}

class _SkinCard extends StatelessWidget {
  final LudoSkinOption option;
  final bool selected;
  final bool locked;
  final double t;
  final VoidCallback onTap;

  const _SkinCard({
    required this.option,
    required this.selected,
    required this.locked,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected ? AppColors.accent : Colors.white.withOpacity(0.10),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: locked ? 0.4 : 1,
                      child: CustomPaint(
                        painter: _SkinPreviewPainter(skin: option.skin, t: t),
                      ),
                    ),
                  ),
                  if (locked)
                    const Center(
                      child: Icon(Icons.lock_rounded,
                          size: 22, color: Colors.white70),
                    ),
                  if (selected)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.accent),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Flexible(
                  child: Text(
                    option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (option.premium) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.6), width: 1),
                    ),
                    child: Text(
                      'PRO',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
                // Glass chip in the sponsor's own primary color, so the brand
                // reads at a glance (same shape language as the PRO chip).
                if (option.sponsor != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: option.sponsor!.primary.withValues(alpha: 0.7),
                          width: 1),
                    ),
                    child: Text(
                      'SPONSORED',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: option.sponsor!.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              option.tagline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints one character "driving in place": gentle heading wiggle + cornering
/// lean so buyers see the motion, not just the sprite.
class _SkinPreviewPainter extends CustomPainter {
  final LudoRiderSkin skin;
  final double t;

  _SkinPreviewPainter({required this.skin, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final wiggle = math.sin(t * 1.6);
    skin.paint(
      canvas,
      RiderFrame(
        center: size.center(Offset.zero),
        sizePx: size.shortestSide * 0.85,
        angle: wiggle * 0.18,
        lean: wiggle * 0.7,
        color: const Color(0xFFEF4444),
        phase: RiderPhase.driving,
        timeSec: t,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SkinPreviewPainter old) =>
      old.t != t || old.skin != skin;
}
