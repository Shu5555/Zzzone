import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SupabaseRankingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // フォールバックとしてJST基準の「論理的な日付」を取得するヘルパー関数
  String getFallbackDateInJST() {
    final now = DateTime.now();
    // タイムゾーンオフセットを考慮してJSTに変換 (UTC+9)
    final jstNow = now.add(const Duration(hours: 9));

    // JSTの午前4時より前なら、日付を1日前に設定
    DateTime targetDate = jstNow;
    if (jstNow.hour < 4) {
      targetDate = jstNow.subtract(const Duration(days: 1));
    }

    // YYYY-MM-DD形式で日付を返す
    return DateFormat('yyyy-MM-dd').format(targetDate);
  }

  Future<List<Map<String, dynamic>>> getRanking({String? date}) async {
    String targetDate;
    if (date != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      targetDate = date;
    } else {
      targetDate = getFallbackDateInJST();
    }

    final response = await _supabase
        .from('sleep_records')
        .select('sleep_duration, created_at, users!left(id, username)')
        .eq('date', targetDate)
        .order('created_at', ascending: false);

    // ユーザーごとに最新のレコード（リストの最初に出てくるもの）だけを抽出する
    final List<Map<String, dynamic>> uniqueUserRecords = [];
    final Set<String> userIds = {};

    for (final record in response) {
      final user = record['users'] as Map<String, dynamic>?;
      final userId = user?['id'] as String?;
      if (userId != null && !userIds.contains(userId)) {
        uniqueUserRecords.add(record);
        userIds.add(userId);
      }
    }

    // 抽出したレコードを睡眠時間でソートする
    uniqueUserRecords.sort((a, b) => (b['sleep_duration'] as int) - (a['sleep_duration'] as int));

    // 上位20件に絞って返却する
    return uniqueUserRecords.take(20).toList();
  }

  Future<void> submitRecord({required String userId, required int sleepDuration, required String date}) async {
    await _supabase.from('sleep_records').upsert(
      {
        'user_id': userId,
        'sleep_duration': sleepDuration,
        'date': date,
      },
      onConflict: 'user_id, date',
    );
  }

  Future<void> updateUser({required String id, required String username}) async {
    if (username.length > 20) {
      throw Exception('Username cannot be longer than 20 characters');
    }
    await _supabase.from('users').upsert(
      {
        'id': id,
        'username': username,
      },
      onConflict: 'id',
    );
  }

  // 新規追加: ユーザーのランキングデータを削除する
  Future<void> deleteUserRankingData(String userId) async {
    await _supabase.from('users').delete().eq('id', userId);
  }

  // 新規追加: ユーザーのすべての睡眠記録を削除する
  Future<void> deleteAllSleepRecords(String userId) async {
    await _supabase.from('sleep_records').delete().eq('user_id', userId);
  }
}