import 'package:flutter/material.dart';

class GachaRarity {
  final String id;
  final String name;
  final Color color;
  final int order;
  final double probability;

  GachaRarity({
    required this.id,
    required this.name,
    required this.color,
    required this.order,
    required this.probability,
  });

  factory GachaRarity.fromJson(Map<String, dynamic> json) {
    return GachaRarity(
      id: json['id'] as String,
      name: json['name'] as String,
      color: _parseColor(json['color'] as String),
      order: json['order'] as int,
      probability: (json['probability'] as num).toDouble(),
    );
  }

  static Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
