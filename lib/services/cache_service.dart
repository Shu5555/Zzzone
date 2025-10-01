import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_cache.dart';

class CacheService {
  static const _key = 'analysis_cache';

  Future<void> saveAnalysis(Map<String, dynamic> result, int latestRecordId) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = AnalysisCache(
      analysisResult: result,
      timestamp: DateTime.now(),
      latestRecordId: latestRecordId,
    );
    await prefs.setString(_key, jsonEncode(cache.toJson()));
  }

  Future<AnalysisCache?> loadAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      try {
        return AnalysisCache.fromJson(jsonDecode(jsonString));
      } catch (e) {
        // JSON解析に失敗した場合はキャッシュをクリア
        await prefs.remove(_key);
        return null;
      }
    }
    return null;
  }
}
