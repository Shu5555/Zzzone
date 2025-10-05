import 'gacha_rarity.dart';

class GachaItem {
  final String id;
  final String rarityId;
  final Map<String, dynamic>? customData;

  // This will be populated at runtime by a service
  GachaRarity? _rarity;

  GachaItem({
    required this.id,
    required this.rarityId,
    this.customData,
  });

  factory GachaItem.fromJson(Map<String, dynamic> json) {
    return GachaItem(
      id: json['id'] as String,
      rarityId: json['rarityId'] as String,
      customData: json['customData'] as Map<String, dynamic>?,
    );
  }

  // Helper to get the quote text from customData
  String? get text => customData?['text'] as String?;

  // Helper to get the author from customData
  String? get author => customData?['author'] as String?;

  /// This is called by a service to attach the full rarity information.
  void setRarity(GachaRarity rarity) {
    _rarity = rarity;
  }

  /// Gets the attached rarity information.
  GachaRarity get rarity {
    if (_rarity == null) {
      throw StateError('Rarity information has not been set for this item. Ensure it is set after loading.');
    }
    return _rarity!;
  }
}