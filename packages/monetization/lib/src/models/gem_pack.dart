import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// An in-app-purchase gem bundle.
@immutable
class GemPack extends Equatable {
  final String id;
  final String name;
  final int gems;
  final double priceUsd;
  final int bonusPercent;

  const GemPack({
    required this.id,
    required this.name,
    required this.gems,
    required this.priceUsd,
    this.bonusPercent = 0,
  });

  /// Total gems including bonus.
  int get totalGems => gems + (gems * bonusPercent ~/ 100);

  // ── Pre-defined packs ──────────────────────────────────────────────────

  static const starter = GemPack(
    id: 'gem_starter',
    name: 'Starter',
    gems: 100,
    priceUsd: 0.99,
  );

  static const popular = GemPack(
    id: 'gem_popular',
    name: 'Popular',
    gems: 500,
    priceUsd: 3.99,
    bonusPercent: 25,
  );

  static const value = GemPack(
    id: 'gem_value',
    name: 'Value',
    gems: 1200,
    priceUsd: 7.99,
    bonusPercent: 50,
  );

  static const premium = GemPack(
    id: 'gem_premium',
    name: 'Premium',
    gems: 3000,
    priceUsd: 19.99,
    bonusPercent: 75,
  );

  static const ultimate = GemPack(
    id: 'gem_ultimate',
    name: 'Ultimate',
    gems: 7500,
    priceUsd: 49.99,
    bonusPercent: 100,
  );

  /// All available gem packs in ascending price order.
  static const List<GemPack> all = [starter, popular, value, premium, ultimate];

  @override
  List<Object?> get props => [id, name, gems, priceUsd, bonusPercent];
}
