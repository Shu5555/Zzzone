import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item.dart';

class GachaDataLoader {
  static Future<GachaConfig> loadConfig(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return GachaConfig.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to load gacha config from $path: $e');
    }
  }

  static Future<List<GachaItem>> loadItems(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final itemsList = jsonData['items'] as List;
      return itemsList
          .map((item) => GachaItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load gacha items from $path: $e');
    }
  }
}
