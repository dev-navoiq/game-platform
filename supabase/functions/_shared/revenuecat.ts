/**
 * RevenueCat REST API v1 helpers for server-side purchase verification.
 *
 * The client never tells us "trust me, I paid" — after the store purchase
 * completes on device we ask RevenueCat (which has already validated the
 * receipt with Apple/Google) whether that user really owns the transaction.
 *
 * Docs: https://www.revenuecat.com/reference/subscribers
 */

export interface RcNonSubscription {
  id: string; // store transaction id
  store_transaction_id?: string;
  purchase_date: string;
  store: string;
  is_sandbox?: boolean;
  price?: number;
  currency?: string;
}

export interface RcSubscription {
  expires_date: string | null;
  purchase_date: string;
  original_purchase_date: string;
  store: string;
  store_transaction_id?: string;
  original_transaction_id?: string;
  unsubscribe_detected_at?: string | null;
  billing_issues_detected_at?: string | null;
  is_sandbox?: boolean;
  period_type?: string;
  price?: number;
  currency?: string;
}

export interface RcSubscriber {
  original_app_user_id: string;
  non_subscriptions: Record<string, RcNonSubscription[]>;
  subscriptions: Record<string, RcSubscription>;
  entitlements: Record<
    string,
    { expires_date: string | null; product_identifier: string; purchase_date: string }
  >;
}

export interface VerifiedPurchase {
  transactionId: string;
  originalTransactionId?: string;
  purchaseDate: string;
  expiresAt?: string;
  store: string;
  priceUsd?: number;
  currencyCode?: string;
  isSandbox: boolean;
  raw: unknown;
}

/** Fetch (or lazily create) the RevenueCat subscriber for a Supabase user id. */
export async function fetchRcSubscriber(appUserId: string): Promise<RcSubscriber> {
  const key = Deno.env.get('REVENUECAT_SECRET_KEY');
  if (!key) throw new Error('REVENUECAT_SECRET_KEY not configured');

  const res = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
    {
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
    },
  );
  if (!res.ok) {
    throw new Error(`RevenueCat API ${res.status}: ${await res.text()}`);
  }
  const json = await res.json();
  return json.subscriber as RcSubscriber;
}

/**
 * Google Play subscriptions are keyed as `productId:basePlanId` in RevenueCat.
 * Match on the bare product id so one catalog row covers both stores.
 */
function matchesStoreProduct(key: string, storeProductId: string): boolean {
  return key === storeProductId || key.startsWith(`${storeProductId}:`);
}

/** Strip a Google base-plan suffix (`product:basePlan` → `product`). */
export function baseStoreProductId(productId: string): string {
  const i = productId.indexOf(':');
  return i === -1 ? productId : productId.slice(0, i);
}

/**
 * Locate a purchase of `storeProductId` on the subscriber.
 *
 * - Consumables (gem packs): the specific transaction must exist. If the
 *   client supplied a transaction id we require an exact match; otherwise the
 *   most recent purchase of that product is used.
 * - Subscriptions: the subscription must be active (not expired). The store
 *   transaction id from RevenueCat is used so this path and the webhook path
 *   share the same idempotency key.
 */
export function findVerifiedPurchase(
  subscriber: RcSubscriber,
  storeProductId: string,
  productType: 'gem_pack' | 'subscription',
  transactionId?: string,
): VerifiedPurchase | null {
  if (productType === 'gem_pack') {
    const entries = Object.entries(subscriber.non_subscriptions ?? {})
      .filter(([key]) => matchesStoreProduct(key, storeProductId))
      .flatMap(([, list]) => list);
    if (entries.length === 0) return null;

    let match: RcNonSubscription | undefined;
    if (transactionId) {
      match = entries.find(
        (e) => e.store_transaction_id === transactionId || e.id === transactionId,
      );
    } else {
      match = [...entries].sort((a, b) => a.purchase_date.localeCompare(b.purchase_date)).pop();
    }
    if (!match) return null;

    return {
      transactionId: match.store_transaction_id ?? match.id,
      purchaseDate: match.purchase_date,
      store: match.store,
      priceUsd: match.price,
      currencyCode: match.currency,
      isSandbox: match.is_sandbox ?? false,
      raw: match,
    };
  }

  // Subscription
  const entry = Object.entries(subscriber.subscriptions ?? {}).find(([key]) =>
    matchesStoreProduct(key, storeProductId)
  );
  if (!entry) return null;
  const [, sub] = entry;

  const expires = sub.expires_date ? new Date(sub.expires_date) : null;
  if (expires && expires.getTime() < Date.now()) return null;

  // Fallback id keeps fulfillment idempotent per billing period even if the
  // store transaction id is absent from the REST payload.
  const txId = sub.store_transaction_id ??
    `rc-sub:${subscriber.original_app_user_id}:${storeProductId}:${sub.purchase_date}`;
  if (!sub.store_transaction_id) {
    console.warn('RevenueCat subscription missing store_transaction_id; using synthetic id', txId);
  }

  return {
    transactionId: txId,
    originalTransactionId: sub.original_transaction_id,
    purchaseDate: sub.purchase_date,
    expiresAt: sub.expires_date ?? undefined,
    store: sub.store,
    priceUsd: sub.price,
    currencyCode: sub.currency,
    isSandbox: sub.is_sandbox ?? false,
    raw: sub,
  };
}
