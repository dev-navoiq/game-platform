import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../shared/widgets/under_construction_banner.dart';
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

            // WIP banner — purchases are not wired to RevenueCat yet.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: UnderConstructionBanner(
                message:
                    'Shop is under construction — purchases are not wired up yet. Browse only.',
              ),
            ),

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

class _GemPacksTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.75,
      children: [
        GemPackCard(
          name: 'Starter',
          gems: 100,
          priceUsd: 0.99,
          onBuy: () {},
        ),
        GemPackCard(
          name: 'Popular',
          gems: 500,
          bonusGems: 125,
          priceUsd: 3.99,
          isPopular: true,
          onBuy: () {},
        ),
        GemPackCard(
          name: 'Value',
          gems: 1200,
          bonusGems: 600,
          priceUsd: 7.99,
          onBuy: () {},
        ),
        GemPackCard(
          name: 'Premium',
          gems: 3000,
          bonusGems: 2250,
          priceUsd: 19.99,
          onBuy: () {},
        ),
        GemPackCard(
          name: 'Ultimate',
          gems: 7500,
          bonusGems: 7500,
          priceUsd: 49.99,
          onBuy: () {},
        ),
      ],
    );
  }
}

class _CardSkinsTab extends ConsumerWidget {
  const _CardSkinsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(cardSkinThemeProvider).id;

    // For now, classic (free) is always owned.
    // In production, owned set comes from SkinService / user_skins table.
    final ownedIds = <String>{'classic'};

    return SkinSelector(
      type: SkinSelectorType.card,
      selectedSkinId: selectedId,
      ownedSkinIds: ownedIds,
      onSelect: (id) {
        ref.read(selectedCardSkinProvider.notifier).state = id;
      },
      onBuy: (id) {
        // TODO: wire to SkinService.purchaseSkin when backend is ready
        final skin = AssetRegistry.instance.getCardSkin(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase ${skin.displayName}: ${skin.priceCoins > 0 ? "${skin.priceCoins} coins" : "${skin.priceGems} gems"}',
            ),
          ),
        );
      },
    );
  }
}

class _RoomThemesTab extends ConsumerWidget {
  const _RoomThemesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(roomSkinThemeProvider).id;

    // Classic (free) is always owned.
    final ownedIds = <String>{'classic'};

    return SkinSelector(
      type: SkinSelectorType.room,
      selectedSkinId: selectedId,
      ownedSkinIds: ownedIds,
      onSelect: (id) {
        ref.read(selectedRoomSkinProvider.notifier).state = id;
      },
      onBuy: (id) {
        final skin = AssetRegistry.instance.getRoomSkin(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase ${skin.displayName}: ${skin.priceCoins > 0 ? "${skin.priceCoins} coins" : "${skin.priceGems} gems"}',
            ),
          ),
        );
      },
    );
  }
}
