# 12 - Monetization & Advertising

> Implement subscription tiers, in-app purchases, and non-intrusive advertising.

## Task

Create a comprehensive monetization system with:
- Three subscription tiers (Free, Pro, Max)
- In-app currency (Coins & Gems)
- Non-intrusive ad placements
- Brand advertising opportunities (room skins, card backs)
- RevenueCat integration
- AdMob integration

---

## Subscription Tiers

### Tier Comparison

| Feature | Free | Pro ($4.99/mo) | Max ($9.99/mo) |
|---------|------|----------------|----------------|
| **Games** | All games | All games | All games |
| **Ads** | Banner ads | No banner ads | No ads at all |
| **Voice Chat** | No | Yes | Yes |
| **Card Skins** | 2 free | 5 exclusive | All skins |
| **Room Skins** | 1 free | 3 exclusive | All skins |
| **Monthly Coins** | 100 | 500 | 2000 |
| **Monthly Gems** | 0 | 50 | 200 |
| **Custom Rooms** | No | Yes | Yes |
| **Private Rooms** | 1/day | Unlimited | Unlimited |
| **Room Size** | Up to 4 | Up to 6 | Up to 8 |
| **Priority Matchmaking** | No | Yes | Yes |
| **Exclusive Emotes** | No | 5 | 20 |
| **Profile Badge** | None | Pro Badge | Max Badge |
| **Statistics** | Basic | Detailed | Full Analytics |
| **Leaderboard Highlight** | No | Silver Frame | Gold Frame |

---

## Monetization Package

```dart
// packages/monetization/lib/src/subscription/subscription_tier.dart

enum SubscriptionTier {
  free,
  pro,
  max,
}

class TierBenefits {
  final SubscriptionTier tier;
  final bool adsEnabled;
  final bool bannerAdsEnabled;
  final bool interstitialAdsEnabled;
  final bool voiceChatEnabled;
  final int monthlyCoinBonus;
  final int monthlyGemBonus;
  final int maxPrivateRoomsPerDay;
  final int maxRoomSize;
  final bool priorityMatchmaking;
  final bool customRooms;
  final List<String> exclusiveSkinIds;
  final List<String> exclusiveEmoteIds;
  final String? profileBadge;
  final String? leaderboardFrame;
  final bool detailedStats;

  const TierBenefits._({
    required this.tier,
    required this.adsEnabled,
    required this.bannerAdsEnabled,
    required this.interstitialAdsEnabled,
    required this.voiceChatEnabled,
    required this.monthlyCoinBonus,
    required this.monthlyGemBonus,
    required this.maxPrivateRoomsPerDay,
    required this.maxRoomSize,
    required this.priorityMatchmaking,
    required this.customRooms,
    required this.exclusiveSkinIds,
    required this.exclusiveEmoteIds,
    this.profileBadge,
    this.leaderboardFrame,
    required this.detailedStats,
  });

  static const free = TierBenefits._(
    tier: SubscriptionTier.free,
    adsEnabled: true,
    bannerAdsEnabled: true,
    interstitialAdsEnabled: true,
    voiceChatEnabled: false,
    monthlyCoinBonus: 100,
    monthlyGemBonus: 0,
    maxPrivateRoomsPerDay: 1,
    maxRoomSize: 4,
    priorityMatchmaking: false,
    customRooms: false,
    exclusiveSkinIds: [],
    exclusiveEmoteIds: [],
    profileBadge: null,
    leaderboardFrame: null,
    detailedStats: false,
  );

  static const pro = TierBenefits._(
    tier: SubscriptionTier.pro,
    adsEnabled: true,
    bannerAdsEnabled: false,
    interstitialAdsEnabled: true, // Only rewarded ads
    voiceChatEnabled: true,
    monthlyCoinBonus: 500,
    monthlyGemBonus: 50,
    maxPrivateRoomsPerDay: -1, // Unlimited
    maxRoomSize: 6,
    priorityMatchmaking: true,
    customRooms: true,
    exclusiveSkinIds: ['pro_cards_gold', 'pro_cards_silver', 'pro_room_vip'],
    exclusiveEmoteIds: ['emote_pro_1', 'emote_pro_2', 'emote_pro_3'],
    profileBadge: 'badge_pro',
    leaderboardFrame: 'frame_silver',
    detailedStats: true,
  );

  static const max = TierBenefits._(
    tier: SubscriptionTier.max,
    adsEnabled: false,
    bannerAdsEnabled: false,
    interstitialAdsEnabled: false,
    voiceChatEnabled: true,
    monthlyCoinBonus: 2000,
    monthlyGemBonus: 200,
    maxPrivateRoomsPerDay: -1,
    maxRoomSize: 8,
    priorityMatchmaking: true,
    customRooms: true,
    exclusiveSkinIds: ['all'], // Access to all skins
    exclusiveEmoteIds: ['all'],
    profileBadge: 'badge_max',
    leaderboardFrame: 'frame_gold',
    detailedStats: true,
  );

  static TierBenefits forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return free;
      case SubscriptionTier.pro:
        return pro;
      case SubscriptionTier.max:
        return max;
    }
  }
}
```

---

## RevenueCat Integration

```dart
// packages/monetization/lib/src/subscription/subscription_service.dart

import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'subscription_tier.dart';

class SubscriptionService {
  static const String _proProductId = 'game_platform_pro_monthly';
  static const String _maxProductId = 'game_platform_max_monthly';
  static const String _proAnnualId = 'game_platform_pro_annual';
  static const String _maxAnnualId = 'game_platform_max_annual';

  final _tierController = StreamController<SubscriptionTier>.broadcast();
  SubscriptionTier _currentTier = SubscriptionTier.free;

  Stream<SubscriptionTier> get tierStream => _tierController.stream;
  SubscriptionTier get currentTier => _currentTier;
  TierBenefits get benefits => TierBenefits.forTier(_currentTier);

  Future<void> initialize(String apiKey, String userId) async {
    await Purchases.configure(
      PurchasesConfiguration(apiKey)..appUserID = userId,
    );

    // Listen to customer info changes
    Purchases.addCustomerInfoUpdateListener((info) {
      _updateTierFromCustomerInfo(info);
    });

    // Get initial status
    final customerInfo = await Purchases.getCustomerInfo();
    _updateTierFromCustomerInfo(customerInfo);
  }

  void _updateTierFromCustomerInfo(CustomerInfo info) {
    final entitlements = info.entitlements.active;

    if (entitlements.containsKey('max') ||
        entitlements.containsKey('max_annual')) {
      _setTier(SubscriptionTier.max);
    } else if (entitlements.containsKey('pro') ||
        entitlements.containsKey('pro_annual')) {
      _setTier(SubscriptionTier.pro);
    } else {
      _setTier(SubscriptionTier.free);
    }
  }

  void _setTier(SubscriptionTier tier) {
    if (_currentTier != tier) {
      _currentTier = tier;
      _tierController.add(tier);
    }
  }

  Future<List<SubscriptionPackage>> getAvailablePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current == null) return [];

      return current.availablePackages.map((package) {
        return SubscriptionPackage(
          identifier: package.identifier,
          productId: package.storeProduct.identifier,
          title: package.storeProduct.title,
          description: package.storeProduct.description,
          price: package.storeProduct.priceString,
          priceAmount: package.storeProduct.price,
          currencyCode: package.storeProduct.currencyCode,
          period: _parsePeriod(package.packageType),
          tier: _tierForPackage(package.identifier),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  SubscriptionPeriod _parsePeriod(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return SubscriptionPeriod.monthly;
      case PackageType.annual:
        return SubscriptionPeriod.annual;
      default:
        return SubscriptionPeriod.monthly;
    }
  }

  SubscriptionTier _tierForPackage(String identifier) {
    if (identifier.contains('max')) {
      return SubscriptionTier.max;
    } else if (identifier.contains('pro')) {
      return SubscriptionTier.pro;
    }
    return SubscriptionTier.free;
  }

  Future<PurchaseResult> purchase(SubscriptionPackage package) async {
    try {
      final offerings = await Purchases.getOfferings();
      final storeProduct = offerings.current?.availablePackages
          .firstWhere((p) => p.identifier == package.identifier);

      if (storeProduct == null) {
        return PurchaseResult.productNotFound;
      }

      final customerInfo = await Purchases.purchasePackage(storeProduct);
      _updateTierFromCustomerInfo(customerInfo);

      return PurchaseResult.success;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled;
      }
      return PurchaseResult.error;
    } catch (e) {
      return PurchaseResult.error;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateTierFromCustomerInfo(customerInfo);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> dispose() async {
    await _tierController.close();
  }
}

class SubscriptionPackage {
  final String identifier;
  final String productId;
  final String title;
  final String description;
  final String price;
  final double priceAmount;
  final String currencyCode;
  final SubscriptionPeriod period;
  final SubscriptionTier tier;

  SubscriptionPackage({
    required this.identifier,
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.priceAmount,
    required this.currencyCode,
    required this.period,
    required this.tier,
  });

  String get savingsText {
    if (period == SubscriptionPeriod.annual) {
      return 'Save 17%';
    }
    return '';
  }
}

enum SubscriptionPeriod { monthly, annual }
enum PurchaseResult { success, cancelled, productNotFound, error }
```

---

## Ad System

### Ad Placements (Non-Intrusive)

```dart
// packages/monetization/lib/src/ads/ad_placements.dart

/// Where ads can appear in the app
enum AdPlacement {
  /// Small banner at bottom of lobby screen
  lobbyBanner,

  /// Interstitial shown after game ends (not during gameplay!)
  gameEndInterstitial,

  /// Rewarded ad for bonus coins
  rewardedCoins,

  /// Native ad in room list
  roomListNative,

  /// Branded room background (sponsor)
  roomBackgroundBrand,

  /// Branded card back (sponsor)
  cardBackBrand,
}

class AdPlacementConfig {
  final AdPlacement placement;
  final bool enabledForFree;
  final bool enabledForPro;
  final bool enabledForMax;
  final Duration? cooldown;
  final int? maxPerSession;
  final String? defaultAdUnitId;

  const AdPlacementConfig({
    required this.placement,
    required this.enabledForFree,
    required this.enabledForPro,
    required this.enabledForMax,
    this.cooldown,
    this.maxPerSession,
    this.defaultAdUnitId,
  });

  static const configs = {
    AdPlacement.lobbyBanner: AdPlacementConfig(
      placement: AdPlacement.lobbyBanner,
      enabledForFree: true,
      enabledForPro: false,
      enabledForMax: false,
      defaultAdUnitId: 'ca-app-pub-xxx/lobby_banner',
    ),
    AdPlacement.gameEndInterstitial: AdPlacementConfig(
      placement: AdPlacement.gameEndInterstitial,
      enabledForFree: true,
      enabledForPro: false,
      enabledForMax: false,
      cooldown: Duration(minutes: 5), // Max 1 every 5 min
      maxPerSession: 3,
      defaultAdUnitId: 'ca-app-pub-xxx/game_end',
    ),
    AdPlacement.rewardedCoins: AdPlacementConfig(
      placement: AdPlacement.rewardedCoins,
      enabledForFree: true,
      enabledForPro: true, // Pro can still watch for bonus
      enabledForMax: true, // Max can still watch for bonus
      cooldown: Duration(hours: 1),
      maxPerSession: 5,
      defaultAdUnitId: 'ca-app-pub-xxx/rewarded_coins',
    ),
    AdPlacement.roomListNative: AdPlacementConfig(
      placement: AdPlacement.roomListNative,
      enabledForFree: true,
      enabledForPro: false,
      enabledForMax: false,
      defaultAdUnitId: 'ca-app-pub-xxx/room_list_native',
    ),
    AdPlacement.roomBackgroundBrand: AdPlacementConfig(
      placement: AdPlacement.roomBackgroundBrand,
      enabledForFree: true,
      enabledForPro: true, // Branded content is opt-in
      enabledForMax: true,
    ),
    AdPlacement.cardBackBrand: AdPlacementConfig(
      placement: AdPlacement.cardBackBrand,
      enabledForFree: true,
      enabledForPro: true,
      enabledForMax: true,
    ),
  };
}
```

### Ad Service

```dart
// packages/monetization/lib/src/ads/ad_service.dart

import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../subscription/subscription_tier.dart';
import 'ad_placements.dart';

class AdService {
  final SubscriptionTier Function() _getCurrentTier;
  final Map<AdPlacement, DateTime> _lastShownTimes = {};
  final Map<AdPlacement, int> _sessionCounts = {};

  BannerAd? _lobbyBannerAd;
  InterstitialAd? _gameEndInterstitialAd;
  RewardedAd? _rewardedAd;

  AdService({required SubscriptionTier Function() getCurrentTier})
      : _getCurrentTier = getCurrentTier;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();

    // Pre-load ads
    _loadInterstitial();
    _loadRewarded();
  }

  /// Check if an ad placement is enabled for current user
  bool isPlacementEnabled(AdPlacement placement) {
    final config = AdPlacementConfig.configs[placement];
    if (config == null) return false;

    final tier = _getCurrentTier();
    switch (tier) {
      case SubscriptionTier.free:
        return config.enabledForFree;
      case SubscriptionTier.pro:
        return config.enabledForPro;
      case SubscriptionTier.max:
        return config.enabledForMax;
    }
  }

  /// Check if ad can be shown (considering cooldowns)
  bool canShowAd(AdPlacement placement) {
    if (!isPlacementEnabled(placement)) return false;

    final config = AdPlacementConfig.configs[placement]!;

    // Check cooldown
    if (config.cooldown != null) {
      final lastShown = _lastShownTimes[placement];
      if (lastShown != null) {
        final elapsed = DateTime.now().difference(lastShown);
        if (elapsed < config.cooldown!) return false;
      }
    }

    // Check session limit
    if (config.maxPerSession != null) {
      final count = _sessionCounts[placement] ?? 0;
      if (count >= config.maxPerSession!) return false;
    }

    return true;
  }

  void _recordAdShown(AdPlacement placement) {
    _lastShownTimes[placement] = DateTime.now();
    _sessionCounts[placement] = (_sessionCounts[placement] ?? 0) + 1;
  }

  // Banner Ad
  Future<BannerAd?> loadLobbyBanner({
    required AdSize size,
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) async {
    if (!isPlacementEnabled(AdPlacement.lobbyBanner)) return null;

    _lobbyBannerAd = BannerAd(
      adUnitId: AdPlacementConfig.configs[AdPlacement.lobbyBanner]!.defaultAdUnitId!,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    );

    await _lobbyBannerAd!.load();
    return _lobbyBannerAd;
  }

  void disposeLobbyBanner() {
    _lobbyBannerAd?.dispose();
    _lobbyBannerAd = null;
  }

  // Interstitial Ad (Game End)
  void _loadInterstitial() {
    if (!isPlacementEnabled(AdPlacement.gameEndInterstitial)) return;

    InterstitialAd.load(
      adUnitId: AdPlacementConfig.configs[AdPlacement.gameEndInterstitial]!.defaultAdUnitId!,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _gameEndInterstitialAd = ad,
        onAdFailedToLoad: (error) => _gameEndInterstitialAd = null,
      ),
    );
  }

  Future<bool> showGameEndInterstitial() async {
    if (!canShowAd(AdPlacement.gameEndInterstitial)) return false;
    if (_gameEndInterstitialAd == null) return false;

    final completer = Completer<bool>();

    _gameEndInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _recordAdShown(AdPlacement.gameEndInterstitial);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial(); // Pre-load next
        completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        completer.complete(false);
      },
    );

    await _gameEndInterstitialAd!.show();
    _gameEndInterstitialAd = null;

    return completer.future;
  }

  // Rewarded Ad
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdPlacementConfig.configs[AdPlacement.rewardedCoins]!.defaultAdUnitId!,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => _rewardedAd = null,
      ),
    );
  }

  Future<RewardedAdResult> showRewardedAd() async {
    if (!canShowAd(AdPlacement.rewardedCoins)) {
      return RewardedAdResult.notAvailable;
    }
    if (_rewardedAd == null) {
      return RewardedAdResult.notLoaded;
    }

    final completer = Completer<RewardedAdResult>();
    RewardItem? earnedReward;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _recordAdShown(AdPlacement.rewardedCoins);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        completer.complete(
          earnedReward != null
              ? RewardedAdResult.rewarded
              : RewardedAdResult.dismissed,
        );
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewarded();
        completer.complete(RewardedAdResult.error);
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        earnedReward = reward;
      },
    );

    _rewardedAd = null;
    return completer.future;
  }

  /// Get reward amount for rewarded ad
  int getRewardedCoinsAmount() {
    // Base amount, can be modified by events/promotions
    return 50;
  }

  void resetSessionCounts() {
    _sessionCounts.clear();
  }

  Future<void> dispose() async {
    _lobbyBannerAd?.dispose();
    _gameEndInterstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

enum RewardedAdResult {
  rewarded,
  dismissed,
  notAvailable,
  notLoaded,
  error,
}
```

---

## Currency System

```dart
// packages/monetization/lib/src/currency/currency_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

enum CurrencyType { coins, gems }

class CurrencyService {
  final SupabaseClient _supabase;
  final String _userId;

  int _coins = 0;
  int _gems = 0;

  int get coins => _coins;
  int get gems => _gems;

  CurrencyService({
    required SupabaseClient supabase,
    required String userId,
  })  : _supabase = supabase,
        _userId = userId;

  Future<void> loadBalance() async {
    final response = await _supabase
        .from('profiles')
        .select('coins, gems')
        .eq('id', _userId)
        .single();

    _coins = response['coins'] as int? ?? 0;
    _gems = response['gems'] as int? ?? 0;
  }

  Future<bool> spend({
    int coins = 0,
    int gems = 0,
    required String reason,
    String? referenceId,
  }) async {
    if (coins > _coins || gems > _gems) {
      return false; // Insufficient balance
    }

    try {
      // Transaction in database
      await _supabase.rpc('spend_currency', params: {
        'user_id': _userId,
        'coin_amount': coins,
        'gem_amount': gems,
        'transaction_type': 'spend',
        'description': reason,
        'reference_id': referenceId,
      });

      _coins -= coins;
      _gems -= gems;

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> earn({
    int coins = 0,
    int gems = 0,
    required String reason,
    String? referenceId,
  }) async {
    try {
      await _supabase.rpc('earn_currency', params: {
        'user_id': _userId,
        'coin_amount': coins,
        'gem_amount': gems,
        'transaction_type': 'reward',
        'description': reason,
        'reference_id': referenceId,
      });

      _coins += coins;
      _gems += gems;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Award daily login bonus
  Future<DailyBonusResult> claimDailyBonus(int consecutiveDays) async {
    // Bonus scales with consecutive days
    final coinBonus = 10 + (consecutiveDays * 5).clamp(0, 50);
    final gemBonus = consecutiveDays >= 7 ? 5 : 0;

    final success = await earn(
      coins: coinBonus,
      gems: gemBonus,
      reason: 'Daily login bonus (day $consecutiveDays)',
    );

    return DailyBonusResult(
      success: success,
      coinsEarned: coinBonus,
      gemsEarned: gemBonus,
      consecutiveDays: consecutiveDays,
    );
  }

  /// Award ad watch bonus
  Future<bool> claimAdWatchBonus(int amount) async {
    return earn(
      coins: amount,
      reason: 'Ad watch reward',
    );
  }
}

class DailyBonusResult {
  final bool success;
  final int coinsEarned;
  final int gemsEarned;
  final int consecutiveDays;

  DailyBonusResult({
    required this.success,
    required this.coinsEarned,
    required this.gemsEarned,
    required this.consecutiveDays,
  });
}
```

---

## Brand Advertising (Room & Card Skins)

```dart
// packages/monetization/lib/src/brand/brand_advertising.dart

/// Sponsored skin that brands can purchase
class BrandSkin {
  final String id;
  final String brandName;
  final String brandLogoUrl;
  final BrandSkinType type;
  final String assetUrl;
  final String? campaignId;
  final DateTime? activeFrom;
  final DateTime? activeUntil;
  final bool isActive;

  const BrandSkin({
    required this.id,
    required this.brandName,
    required this.brandLogoUrl,
    required this.type,
    required this.assetUrl,
    this.campaignId,
    this.activeFrom,
    this.activeUntil,
    this.isActive = true,
  });

  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (activeFrom != null && now.isBefore(activeFrom!)) return false;
    if (activeUntil != null && now.isAfter(activeUntil!)) return false;
    return true;
  }
}

enum BrandSkinType {
  roomBackground,
  cardBack,
  tableFelt,
  avatar_frame,
}

class BrandAdvertisingService {
  final SupabaseClient _supabase;

  List<BrandSkin> _activeBrandSkins = [];

  BrandAdvertisingService({required SupabaseClient supabase})
      : _supabase = supabase;

  Future<void> loadActiveBrands() async {
    final response = await _supabase
        .from('skins')
        .select()
        .not('brand_name', 'is', null)
        .or('available_from.is.null,available_from.lte.${DateTime.now().toIso8601String()}')
        .or('available_until.is.null,available_until.gte.${DateTime.now().toIso8601String()}');

    _activeBrandSkins = response.map((row) => BrandSkin(
      id: row['skin_id'] as String,
      brandName: row['brand_name'] as String,
      brandLogoUrl: row['brand_logo_url'] as String? ?? '',
      type: BrandSkinType.values.byName(row['skin_type'] as String),
      assetUrl: row['asset_bundle_url'] as String? ?? '',
      campaignId: row['campaign_id'] as String?,
      activeFrom: row['available_from'] != null
          ? DateTime.parse(row['available_from'] as String)
          : null,
      activeUntil: row['available_until'] != null
          ? DateTime.parse(row['available_until'] as String)
          : null,
    )).toList();
  }

  List<BrandSkin> getActiveBrands({BrandSkinType? type}) {
    var skins = _activeBrandSkins.where((s) => s.isCurrentlyActive);
    if (type != null) {
      skins = skins.where((s) => s.type == type);
    }
    return skins.toList();
  }

  /// Record impression when brand content is shown
  Future<void> recordImpression({
    required String skinId,
    required String roomId,
    String? userId,
  }) async {
    final skin = _activeBrandSkins.firstWhere(
      (s) => s.id == skinId,
      orElse: () => throw Exception('Skin not found'),
    );

    await _supabase.from('ad_impressions').insert({
      'user_id': userId,
      'ad_placement': skin.type.name,
      'ad_unit_id': skinId,
      'sponsor_name': skin.brandName,
      'campaign_id': skin.campaignId,
      'room_id': roomId,
    });
  }
}
```

---

## Subscription UI

```dart
// lib/features/shop/presentation/screens/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Tier comparison
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _TierCard(
                      tier: SubscriptionTier.free,
                      isCurrent: true,
                      price: 'Free',
                      features: [
                        'All games available',
                        'Banner ads',
                        '100 coins/month',
                        '1 private room/day',
                      ],
                    ),

                    SizedBox(height: 16),

                    _TierCard(
                      tier: SubscriptionTier.pro,
                      isCurrent: false,
                      price: '\$4.99/month',
                      annualPrice: '\$49.99/year (save 17%)',
                      isRecommended: true,
                      features: [
                        'No banner ads',
                        'Voice chat enabled',
                        '500 coins + 50 gems/month',
                        'Unlimited private rooms',
                        '5 exclusive skins',
                        'Priority matchmaking',
                        'Pro badge',
                      ],
                      onSubscribe: () => _subscribe(context, SubscriptionTier.pro),
                    ),

                    SizedBox(height: 16),

                    _TierCard(
                      tier: SubscriptionTier.max,
                      isCurrent: false,
                      price: '\$9.99/month',
                      annualPrice: '\$99.99/year (save 17%)',
                      features: [
                        'Completely ad-free',
                        'Voice chat enabled',
                        '2000 coins + 200 gems/month',
                        'Unlimited private rooms',
                        'ALL skins unlocked',
                        'Priority matchmaking',
                        'Max badge + Gold frame',
                        'Full analytics',
                      ],
                      onSubscribe: () => _subscribe(context, SubscriptionTier.max),
                    ),
                  ],
                ),
              ),
            ),

            // Restore purchases
            TextButton(
              onPressed: () => _restorePurchases(context),
              child: Text('Restore Purchases'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final SubscriptionTier tier;
  final bool isCurrent;
  final String price;
  final String? annualPrice;
  final List<String> features;
  final bool isRecommended;
  final VoidCallback? onSubscribe;

  // ... implementation
}
```

---

## Expected Output

- Complete subscription system with Free/Pro/Max tiers
- RevenueCat integration for IAP
- Non-intrusive ad placements (lobby banner, game-end interstitial, rewarded)
- Brand advertising system for room/card skins
- Currency system (coins/gems) with transactions
- Daily login bonuses
- Subscription comparison UI
- Ad tracking and analytics integration
