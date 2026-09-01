import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { debitCurrency } from '../_shared/currency.ts';

/**
 * Purchase a shop item (card skin, room theme, avatar frame) with coins or gems.
 *
 * Flow:
 * 1. Authenticate user
 * 2. Fetch skin from skins table (by ID or asset_key)
 * 3. Check if user already owns it
 * 4. Determine currency and amount based on skin pricing
 * 5. Debit coins or gems atomically
 * 6. Insert ownership record in user_skins
 * 7. Return success with updated balance
 *
 * Security:
 * - Uses server-authoritative debitCurrency (can't manipulate price)
 * - Unique constraint on user_skins prevents duplicate purchases
 * - Price comes from database, not client
 */

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    // Parse request body
    const body = await req.json().catch(() => ({}));
    const skinId = body.skin_id as string | undefined;
    const assetKey = body.asset_key as string | undefined;

    // Validate input: must provide either skin_id or asset_key
    if (!skinId && !assetKey) {
      return errorResponse('Must provide either skin_id or asset_key', 400, 'MISSING_IDENTIFIER');
    }

    // 1. Fetch skin from database
    let query = admin.from('skins').select('*');
    if (skinId) {
      query = query.eq('id', skinId);
    } else {
      query = query.eq('asset_key', assetKey);
    }

    const { data: skin, error: skinErr } = await query.maybeSingle();

    if (skinErr) {
      console.error('Error fetching skin:', skinErr);
      return errorResponse('Failed to fetch skin', 500);
    }

    if (!skin) {
      return errorResponse('Skin not found', 404, 'SKIN_NOT_FOUND');
    }

    // 2. Check if skin is free (default skins are auto-owned)
    if (skin.is_default || (skin.price_coins === 0 && skin.price_gems === 0)) {
      return errorResponse('This skin is free and cannot be purchased', 400, 'SKIN_IS_FREE');
    }

    // 3. Check if user already owns this skin
    const { data: existingOwnership } = await admin
      .from('user_skins')
      .select('id')
      .eq('user_id', user.id)
      .eq('skin_id', skin.id)
      .maybeSingle();

    if (existingOwnership) {
      return errorResponse('You already own this skin', 400, 'ALREADY_OWNED');
    }

    // 4. Determine currency and amount
    // If skin has coin price > 0, use coins. Otherwise use gems.
    const useCurrency: 'coins' | 'gems' = skin.price_coins > 0 ? 'coins' : 'gems';
    const amount = useCurrency === 'coins' ? skin.price_coins : skin.price_gems;

    if (amount <= 0) {
      return errorResponse('Skin has invalid price', 500, 'INVALID_PRICE');
    }

    // 5. Debit currency (throws if insufficient balance)
    let balanceAfter: number;
    try {
      const result = await debitCurrency(
        admin,
        user.id,
        useCurrency,
        amount,
        'shop_item_purchase',
        skin.id, // reference_id = skin.id for audit trail
      );
      balanceAfter = result.balance_after;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.startsWith('Insufficient')) {
        return errorResponse(msg, 400, 'INSUFFICIENT_FUNDS');
      }
      throw e;
    }

    // 6. Grant ownership (insert into user_skins)
    const { error: ownershipErr } = await admin.from('user_skins').insert({
      user_id: user.id,
      skin_id: skin.id,
      is_equipped: false, // User must manually equip after purchase
      acquired_at: new Date().toISOString(),
    });

    if (ownershipErr) {
      console.error('Error granting skin ownership:', ownershipErr);
      // If unique constraint violation, skin was purchased by another concurrent request
      if (ownershipErr.code === '23505') {
        return errorResponse('Race condition: skin already owned', 400, 'ALREADY_OWNED');
      }
      return errorResponse('Failed to grant ownership', 500);
    }

    console.log('Shop item purchased:', {
      userId: user.id,
      skinName: skin.name,
      skinType: skin.skin_type,
      currency: useCurrency,
      amount,
      balanceAfter,
    });

    // 7. Return success
    return jsonResponse({
      success: true,
      skin: {
        id: skin.id,
        name: skin.name,
        skin_type: skin.skin_type,
        asset_key: skin.asset_key,
      },
      currency: useCurrency,
      amount_paid: amount,
      balance_after: balanceAfter,
    });
  } catch (error) {
    console.error('purchase-shop-item error:', error);
    return errorResponse('Internal server error', 500);
  }
});
