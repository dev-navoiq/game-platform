import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/di/monetization_providers.dart';
import '../../../core/services/ad_mode.dart';
import '../../../core/services/game_end_ad_controller.dart';
import '../../../core/services/house_ads/house_ad_catalog.dart';
import '../../../core/services/house_ads/house_ad_creative.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../../../shared/widgets/house_banner_ad.dart';
import '../../../shared/widgets/house_interstitial_overlay.dart';

/// Dev-only Ad Gallery (`/dev/ads`).
///
/// Lets the team preview every house creative in both slot forms (banner +
/// full-screen interstitial), flip the live ad mode (house/google/mock),
/// trigger a real game-end interstitial flow (bypassing cadence), and
/// preview the HTML5 playable-ad creatives in an embedded webview.
///
/// Reach it via Settings → Developer → "Ad Gallery" (debug builds) or by
/// navigating to `/dev/ads` directly.
class AdGalleryScreen extends ConsumerWidget {
  const AdGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(adModeProvider);

    return Scaffold(
      backgroundColor: AppColors.feltDark,
      appBar: AppBar(
        title: const Text('Ad Gallery (dev)'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textOnFelt,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Ad mode switcher ─────────────────────────────────────────
          _sectionTitle('Ad mode'),
          const SizedBox(height: 8),
          SegmentedButton<AdMode>(
            segments: const [
              ButtonSegment(value: AdMode.house, label: Text('House')),
              ButtonSegment(value: AdMode.google, label: Text('Google')),
              ButtonSegment(value: AdMode.mock, label: Text('Mock')),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                ref.read(adModeProvider.notifier).state = selection.first,
            style: SegmentedButton.styleFrom(
              foregroundColor: AppColors.textFeltMuted,
              selectedForegroundColor: AppColors.textOnFelt,
              selectedBackgroundColor: AppColors.accent.withValues(alpha: 0.35),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overrides the ad slots app-wide for this session. '
            'Default: house on dev/staging, google on production.',
            style: TextStyle(
                fontSize: 12, color: AppColors.textFeltMuted.withValues(alpha: 0.8)),
          ),

          // ── Live slots ───────────────────────────────────────────────
          const SizedBox(height: 24),
          _sectionTitle('Live slots (current mode: ${mode.name})'),
          const SizedBox(height: 4),
          Text(
            'The real BannerAdWidget, exactly as free-tier users see it. '
            'Hidden entirely for Pro/Max.',
            style: TextStyle(
                fontSize: 12, color: AppColors.textFeltMuted.withValues(alpha: 0.8)),
          ),
          const BannerAdWidget(),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.85),
            ),
            onPressed: () => ref
                .read(gameEndAdControllerProvider)
                .debugShowGameEndInterstitial(context),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Trigger game-end interstitial (skips cadence)'),
          ),

          // ── House creative catalog ───────────────────────────────────
          const SizedBox(height: 24),
          _sectionTitle('House creatives (${kHouseAdCatalog.length})'),
          const SizedBox(height: 4),
          Text(
            'Banner form below; tap a card to preview its full-screen '
            'interstitial form.',
            style: TextStyle(
                fontSize: 12, color: AppColors.textFeltMuted.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          for (final creative in kHouseAdCatalog) ...[
            _CreativePreviewCard(creative: creative),
            const SizedBox(height: 12),
          ],

          // ── HTML5 playables ──────────────────────────────────────────
          const SizedBox(height: 12),
          _sectionTitle('HTML5 playable ads'),
          const SizedBox(height: 4),
          Text(
            'Self-contained playable creatives from marketing/playables/, '
            'bundled as assets and rendered in a webview.',
            style: TextStyle(
                fontSize: 12, color: AppColors.textFeltMuted.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          const _PlayablePreviewCard(
            title: 'Ludo playable',
            assetPath: 'assets/playables/ludo.html',
            sourcePath: 'marketing/playables/ludo/index.html',
          ),
          const SizedBox(height: 12),
          const _PlayablePreviewCard(
            title: 'Hearts playable',
            assetPath: 'assets/playables/hearts.html',
            sourcePath: 'marketing/playables/hearts/index.html',
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnFelt,
      ),
    );
  }
}

/// One catalog creative: id/route header, banner-form preview, and a button
/// to preview the interstitial form.
class _CreativePreviewCard extends StatelessWidget {
  final HouseAdCreative creative;

  const _CreativePreviewCard({required this.creative});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${creative.id}  →  ${creative.route ?? '(no destination)'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textFeltMuted.withValues(alpha: 0.9),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => HouseInterstitialOverlay.show(
                  context: context,
                  creative: creative,
                  // Short delay so previewing is fast.
                  closeDelay: const Duration(seconds: 1),
                ),
                icon: const Icon(Icons.fullscreen, size: 16),
                label: const Text('Interstitial'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Banner form. Tap navigates like the real slot would.
          HouseBannerAd(creative: creative),
        ],
      ),
    );
  }
}

/// Lazy webview preview of a bundled HTML5 playable. The webview is only
/// created when "Load preview" is tapped, so the gallery stays light.
class _PlayablePreviewCard extends StatefulWidget {
  final String title;
  final String assetPath;
  final String sourcePath;

  const _PlayablePreviewCard({
    required this.title,
    required this.assetPath,
    required this.sourcePath,
  });

  @override
  State<_PlayablePreviewCard> createState() => _PlayablePreviewCardState();
}

class _PlayablePreviewCardState extends State<_PlayablePreviewCard> {
  WebViewController? _controller;
  String? _error;

  Future<void> _load() async {
    try {
      final html = await rootBundle.loadString(widget.assetPath);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.feltDark);
      await controller.loadHtmlString(html);
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load playable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnFelt,
                  ),
                ),
              ),
              if (_controller == null)
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Load preview'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentSoft,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          Text(
            widget.sourcePath,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.textFeltMuted.withValues(alpha: 0.9),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
          if (_controller != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 480,
                child: WebViewWidget(controller: _controller!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
