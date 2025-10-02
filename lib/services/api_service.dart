import 'package:supabase_flutter/supabase_flutter.dart'; // For SupabaseException
import 'package:zzzone/services/supabase_ranking_service.dart'; // Import the new service

class ApiService {
  final SupabaseRankingService _supabaseRankingService = SupabaseRankingService();

  /// ユーザー情報を更新または作成する
  Future<void> updateUser(String id, String username) async {
    try {
      await _supabaseRankingService.updateUser(id: id, username: username);
    } on SupabaseException catch (e) {
      throw Exception('Failed to update user: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// 睡眠記録を送信する
  Future<void> submitRecord(String userId, int sleepDuration, String date) async {
    try {
      await _supabaseRankingService.submitRecord(
          userId: userId, sleepDuration: sleepDuration, date: date);
    } on SupabaseException catch (e) {
      throw Exception('Failed to submit record: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// ランキングデータを取得する
  Future<List<Map<String, dynamic>>> getRanking(String? date) async {
    try {
      return await _supabaseRankingService.getRanking(date: date);
    } on SupabaseException catch (e) {
      throw Exception('Failed to get ranking: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}