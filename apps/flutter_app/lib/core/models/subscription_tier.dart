enum SubscriptionTier {
  free(
    monthlyPrice: 0.0,
    hasAds: true,
    voiceMinutes: 2,
    monthlyCoins: 200,
    monthlyGems: 0,
    maxPrivateRoomsPerDay: 1,
    maxRoomSize: 4,
    friendListCap: 50,
    spectatorSlots: 2,
    productId: '',
  ),
  pro(
    monthlyPrice: 3.99,
    hasAds: false,
    voiceMinutes: null,
    monthlyCoins: 800,
    monthlyGems: 80,
    maxPrivateRoomsPerDay: -1,
    maxRoomSize: 6,
    friendListCap: 200,
    spectatorSlots: 5,
    productId: 'pro_monthly',
  ),
  max(
    monthlyPrice: 7.99,
    hasAds: false,
    voiceMinutes: null,
    monthlyCoins: 2500,
    monthlyGems: 300,
    maxPrivateRoomsPerDay: -1,
    maxRoomSize: 8,
    friendListCap: -1,
    spectatorSlots: 10,
    productId: 'max_monthly',
  );

  const SubscriptionTier({
    required this.monthlyPrice,
    required this.hasAds,
    required this.voiceMinutes,
    required this.monthlyCoins,
    required this.monthlyGems,
    required this.maxPrivateRoomsPerDay,
    required this.maxRoomSize,
    required this.friendListCap,
    required this.spectatorSlots,
    required this.productId,
  });

  final double monthlyPrice;
  final bool hasAds;
  final int? voiceMinutes; // null = unlimited
  final int monthlyCoins;
  final int monthlyGems;
  final int maxPrivateRoomsPerDay; // -1 = unlimited
  final int maxRoomSize;
  final int friendListCap; // -1 = unlimited
  final int spectatorSlots;
  final String productId;
}
