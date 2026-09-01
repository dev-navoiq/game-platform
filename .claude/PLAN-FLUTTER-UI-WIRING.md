# Implementation Plan: Flutter UI Wiring (Phase 1 Completion)

**Goal**: Wire the shop screen to enable coin-based purchases for skins and themes

**Estimated Time**: 1-2 hours

**What Users Get**: Ability to spend coins/gems on card skins and room themes

---

## Current State

**Backend Ready** ✅
- Edge function: `purchase-shop-item` deployed
- Database: `skins` and `user_skins` tables exist
- Currency: Debit/credit functions working
- Idempotency: Duplicate prevention working

**Frontend Needs Work** ⏳
- Shop screen shows "under construction" banner
- `onBuy` callbacks show snackbar only
- No actual purchase calls to backend
- No ownership tracking from server

---

## Implementation Steps

### Step 1: Create Payment Repository

**File**: `apps/flutter_app/lib/features/shop/data/shop_repository.dart`

Create repository to call the backend function:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ShopRepository {
  final SupabaseClient _supabase;

  ShopRepository(this._supabase);

  /// Purchase a skin or theme with coins or gems
  Future<PurchaseResult> purchaseShopItem({
    required String assetKey,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'purchase-shop-item',
        body: {'asset_key': assetKey},
      );

      if (response.status != 200) {
        throw Exception('Purchase failed: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      return PurchaseResult.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Get owned skins for current user
  Future<List<String>> getOwnedSkins() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('user_skins')
        .select('skin_id, skins!inner(asset_key)')
        .eq('user_id', userId);

    return (response as List)
        .map((row) => row['skins']['asset_key'] as String)
        .toList();
  }
}

class PurchaseResult {
  final bool success;
  final String skinName;
  final String currency;
  final int amountPaid;
  final int balanceAfter;

  PurchaseResult({
    required this.success,
    required this.skinName,
    required this.currency,
    required this.amountPaid,
    required this.balanceAfter,
  });

  factory PurchaseResult.fromJson(Map<String, dynamic> json) {
    return PurchaseResult(
      success: json['success'] ?? false,
      skinName: json['skin']?['name'] ?? '',
      currency: json['currency'] ?? '',
      amountPaid: json['amount_paid'] ?? 0,
      balanceAfter: json['balance_after'] ?? 0,
    );
  }
}
```

---

### Step 2: Add Provider

**File**: `apps/flutter_app/lib/features/shop/providers/shop_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/shop_repository.dart';
import '../../../core/di/providers.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(ref.watch(supabaseProvider));
});

/// Owned skin IDs provider - invalidate after purchase
final ownedSkinsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(shopRepositoryProvider);
  return repository.getOwnedSkins();
});
```

---

### Step 3: Update Shop Screen - Card Skins Tab

**File**: `apps/flutter_app/lib/features/shop/presentation/shop_screen.dart`

Update the `_CardSkinsTab` widget:

```dart
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
        ownedSkinIds: ownedIds.toSet(),
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
```

---

### Step 4: Update Room Themes Tab

Same pattern as card skins. Update `_RoomThemesTab`:

```dart
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
        ownedSkinIds: ownedIds.toSet(),
        onSelect: (id) {
          ref.read(selectedRoomSkinProvider.notifier).state = id;
        },
        onBuy: (id) => _handlePurchase(context, ref, id),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  // Same _handlePurchase and _getErrorMessage as _CardSkinsTab
}
```

---

### Step 5: Remove "Under Construction" Banner

In `shop_screen.dart`, remove or comment out:

```dart
// Remove this:
// const Padding(
//   padding: EdgeInsets.symmetric(horizontal: 16),
//   child: UnderConstructionBanner(
//     message: 'Shop is under construction — purchases are not wired up yet. Browse only.',
//   ),
// ),
```

---

### Step 6: Update Currency Balance Provider

Ensure currency balance refreshes after purchase.

**File**: `apps/flutter_app/lib/core/di/providers.dart`

Make sure `currencyBalanceProvider` is defined and can be invalidated:

```dart
final currencyBalanceProvider = FutureProvider<CurrencyBalance>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    return CurrencyBalance(coins: 0, gems: 0);
  }

  final response = await supabase
      .from('profiles')
      .select('coins, gems')
      .eq('id', userId)
      .single();

  return CurrencyBalance(
    coins: response['coins'] ?? 0,
    gems: response['gems'] ?? 0,
  );
});

class CurrencyBalance {
  final int coins;
  final int gems;

  CurrencyBalance({required this.coins, required this.gems});
}
```

---

## Testing Steps

### Local Testing

1. **Start local Supabase**:
   ```bash
   supabase start
   supabase functions serve &
   ```

2. **Run Flutter app**:
   ```bash
   cd apps/flutter_app
   flutter run -d macos --dart-define=ENV=development
   ```

3. **Test purchase flow**:
   - Log in with a test account
   - Go to Shop → Card Skins tab
   - Note current coin balance
   - Click "Buy" on a skin that costs coins (e.g., "Modern" - 2000 coins)
   - Verify:
     - Loading indicator appears
     - Success message shows
     - Coin balance decreases by 2000
     - Skin becomes "owned" (green checkmark)
     - Can equip the skin

4. **Test error cases**:
   - Try buying same skin again → Should show "already own"
   - Try buying expensive skin without funds → Should show "insufficient funds"

### Staging Testing

1. **Deploy to staging** (if needed):
   ```bash
   # Already deployed! Just test with staging env
   flutter run -d ios --dart-define=ENV=staging
   ```

2. **Test with real staging data**

---

## Success Criteria

- ✅ Users can purchase skins with coins
- ✅ Users can purchase themes with gems
- ✅ Balance updates immediately after purchase
- ✅ Owned skins show as "owned" in UI
- ✅ Duplicate purchase prevented
- ✅ Insufficient funds error shown clearly
- ✅ Currency display refreshes after purchase

---

## Files to Modify

1. **New**: `apps/flutter_app/lib/features/shop/data/shop_repository.dart`
2. **New**: `apps/flutter_app/lib/features/shop/providers/shop_providers.dart`
3. **Update**: `apps/flutter_app/lib/features/shop/presentation/shop_screen.dart`
4. **Verify**: `apps/flutter_app/lib/core/di/providers.dart` (currency balance)

---

## Troubleshooting

### "Edge function not found"
```bash
# Check function is serving
supabase functions list --linked

# Restart if needed
supabase functions serve
```

### "Insufficient funds" but balance is high
- Check if skin price matches database (`skins` table)
- Verify currency type (coins vs gems)

### Owned skins not showing
- Check `user_skins` table has records
- Verify `getOwnedSkins()` query is correct
- Check auth user ID is valid

### Purchase succeeds but UI doesn't update
- Ensure `ref.invalidate(ownedSkinsProvider)` is called
- Ensure `ref.invalidate(currencyBalanceProvider)` is called
- Check provider dependencies

---

## Next Steps After Completion

1. Deploy to production
2. Monitor purchase logs in Supabase dashboard
3. Start Phase 2: Stripe integration for gem purchases
