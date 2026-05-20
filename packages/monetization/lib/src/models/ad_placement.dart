import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Types of ads shown in the app.
enum AdType { banner, interstitial, rewarded, native }

/// Named placements where ads appear.
enum AdPlacement {
  lobbyBanner,
  gameEndInterstitial,
  rewardedDoubleCoins,
  lobbyNative,
}

/// Record of a single ad impression for analytics and rate-limiting.
@immutable
class AdImpression extends Equatable {
  final String id;
  final String userId;
  final AdType adType;
  final AdPlacement placement;
  final DateTime watchedAt;

  const AdImpression({
    required this.id,
    required this.userId,
    required this.adType,
    required this.placement,
    required this.watchedAt,
  });

  @override
  List<Object?> get props => [id, userId, adType, placement, watchedAt];
}
