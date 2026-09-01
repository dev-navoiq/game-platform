import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monetization/monetization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/assets/asset_registry.dart';
import '../../../core/di/monetization_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/skin_theme_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/currency_display.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/skins/skin_selector.dart';
import '../providers/shop_providers.dart';
import 'widgets/gem_pack_card.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
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
          title: 'Shop',
          actions: [
            CurrencyDisplay(
              coins: ref.watch(currencyBalanceProvider).coins,
              gems: ref.watch(currencyBalanceProvider).gems,
              compact: true,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
                height: MediaQuery.of(context).padding.top + 56 + 8),

            // Subscription upsell banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.subscription),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.3),
                        AppColors.accent.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upgrade to Pro',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'No ads + 800 daily coins',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.15),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.accent,
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textOnFelt,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Gem Packs'),
                    Tab(text: 'Card Skins'),
                    Tab(text: 'Themes'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _GemPacksTab(),
                  _CardSkinsTab(key: const Key('card-skins-tab')),
                  _RoomThemesTab(key: const Key('room-themes-tab')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GemPacksTab extends ConsumerWidget {
  const _GemPacksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use GemPack.all from the monetization package for consistency
    final packs = GemPack.all;

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.75,
      children: [
        for (final pack in packs)
          GemPackCard(
            name: pack.name,
            gems: pack.gems,
            bonusGems: pack.gems * pack.bonusPercent ~/ 100,
            priceUsd: pack.priceUsd,
            isPopular: pack.id == 'gem_popular',
            onBuy: () => _handlePurchase(context, ref, pack.id),
          ),
      ],
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    WidgetRef ref,
    String productKey,
  ) async {
    // Web uses Stripe checkout
    if (kIsWeb) {
      await _handleWebPurchase(context, ref, productKey);
    } else {
      // Native platforms use RevenueCat (not yet implemented)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Native purchases coming soon!'),
        ),
      );
    }
  }

  Future<void> _handleWebPurchase(
    BuildContext context,
    WidgetRef ref,
    String productKey,
  ) async {
    final paymentService = ref.read(webPaymentServiceProvider);
    if (paymentService == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Build success/cancel URLs
      final currentUrl = Uri.base.toString().split('?').first;
      final successUrl = '$currentUrl?payment_success=true&session_id={CHECKOUT_SESSION_ID}';
      final cancelUrl = '$currentUrl?payment_cancelled=true';

      // Create checkout session
      final session = await paymentService.createCheckoutSession(
        productKey: productKey,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );

      // Dismiss loading
      if (context.mounted) Navigator.of(context).pop();

      // Redirect to Stripe Checkout
      final uri = Uri.parse(session.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        throw WebPaymentException('Could not open payment page');
      }
    } catch (e) {
      // Dismiss loading
      if (context.mounted) Navigator.of(context).pop();

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CardSkinsTab extends ConsumerWidget {
  const _CardSkinsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(cardSkinThemeProvider).id;
    final ownedSkinsAsync = ref.watch(ownedSkinsProvider);

    return ownedSkinsAsync.when(
      data: (ownedIds) => SkinSelector(
        type: SkinSelectorType.card,
        selectedSkinId: selectedId,
        ownedSkinIds: ownedIds,
        onSelect: (id) {
          ref.read(selectedCardSkinProvider.notifier).state = id;
        },
        onBuy: (id) => _handlePurchase(context, ref, id),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    WidgetRef ref,
    String assetKey,
  ) async {
    final skin = AssetRegistry.instance.getCardSkin(assetKey);
    final repository = ref.read(shopRepositoryProvider);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Call backend
      final result = await repository.purchaseShopItem(assetKey: assetKey);

      // Dismiss loading
      if (context.mounted) Navigator.of(context).pop();

      // Refresh owned skins and currency balance
      ref.invalidate(ownedSkinsProvider);
      ref.invalidate(currencyBalanceProvider);

      // Show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Purchased ${skin.displayName} for ${result.amountPaid} ${result.currency}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Dismiss loading
      if (context.mounted) Navigator.of(context).pop();

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('insufficient')) {
      return '❌ Insufficient funds';
    } else if (errorStr.contains('already own')) {
      return '⚠️ You already own this skin';
    } else {
      return '❌ Purchase failed: ${error.toString()}';
    }
  }
}

class _RoomThemesTab extends ConsumerWidget {
  const _RoomThemesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(roomSkinThemeProvider).id;
    final ownedSkinsAsync = ref.watch(ownedSkinsProvider);

    return ownedSkinsAsync.when(
      data: (ownedIds) => SkinSelector(
        type: SkinSelectorType.room,
        selectedSkinId: selectedId,
        ownedSkinIds: ownedIds,
        onSelect: (id) {
          ref.read(selectedRoomSkinProvider.notifier).state = id;
        },
        onBuy: (id) => _handlePurchase(context, ref, id),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    WidgetRef ref,
    String assetKey,
  ) async {
    final skin = AssetRegistry.instance.getRoomSkin(assetKey);
    final repository = ref.read(shopRepositoryProvider);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Call backend
      final result = await repository.purchaseShopItem(assetKey: assetKey);

      // Dismiss loading
      if (context.mounted) Navigator.of(context).pop();

      // Refresh owned skins and currency balance
      ref.invalidate(ownedSkinsProvider);
      ref.invalidate(currencyBalanceProvider);

      // Show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Purchased ${skin.displayName} for ${result.amountPaid} ${result.currency}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Dismiss loading
      if (context.mounted) Navigator.of(context).pop();

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('insufficient')) {
      return '❌ Insufficient funds';
    } else if (errorStr.contains('already own')) {
      return '⚠️ You already own this skin';
    } else {
      return '❌ Purchase failed: ${error.toString()}';
    }
  }
}
