import 'gacha_rarity.dart';

class GachaConfig {
  final int singlePullCost;
  final int multiPullCost;
  final int multiPullCount;
  final List<GachaRarity> rarities;

  GachaConfig({
    required this.singlePullCost,
    required this.multiPullCost,
    required this.multiPullCount,
    required this.rarities,
  });

  factory GachaConfig.fromJson(Map<String, dynamic> json) {
    final raritiesList = (json['rarities'] as List)
        .map((r) => GachaRarity.fromJson(r as Map<String, dynamic>))
        .toList();

    return GachaConfig(
      singlePullCost: json['costs']['singlePull'] as int,
      multiPullCost: json['costs']['multiPull'] as int,
      multiPullCount: json['costs']['multiPullCount'] as int,
      rarities: raritiesList,
    );
  }
}