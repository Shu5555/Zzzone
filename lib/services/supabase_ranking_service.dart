import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SupabaseRankingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String getLogicalDateInJST() {
    final now = DateTime.now();
    DateTime targetDate = now;
    if (now.hour < 4) {
      targetDate = now.subtract(const Duration(days: 1));
    }
    return DateFormat('yyyy-MM-dd').format(targetDate);
  }

  Future<List<Map<String, dynamic>>> getRanking({String? date}) async {
    final targetDate = date ?? getLogicalDateInJST();

    final response = await _supabase
        .from('sleep_records')
        .select('sleep_duration, created_at, users!inner(id, username, background_preference)') // inner join to ensure user exists
        .eq('date', targetDate)
        .order('created_at', ascending: false);

    final Map<String, Map<String, dynamic>> latestRecords = {};
    for (final record in response) {
      final userId = record['users']['id'];
      if (!latestRecords.containsKey(userId)) {
        latestRecords[userId] = record;
      }
    }

    final sortedRecords = latestRecords.values.toList();
    sortedRecords.sort((a, b) => (b['sleep_duration'] as int).compareTo(a['sleep_duration'] as int));

    return sortedRecords.take(20).toList();
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      // Handle cases where user is not found or other errors
      return null;
    }
  }

  Future<void> submitRecord({
    required String userId,
    required String dataId,
    required int sleepDuration,
    required String date,
  }) async {
    await _supabase.from('sleep_records').upsert(
      {
        'user_id': userId,
        'date': date,
        'sleep_duration': sleepDuration,
        'data_id': dataId, // Add dataId to the payload
      },
      onConflict: 'user_id, date', // Assumes a UNIQUE constraint on (user_id, date)
    );
  }

  Future<void> updateUser({required String id, required String username, String? backgroundPreference, int? sleepCoins}) async {
    if (username.length > 20) {
      throw Exception('Username cannot be longer than 20 characters');
    }
    try {
      final Map<String, dynamic> updateData = {
        'id': id,
        'username': username,
      };

      if (backgroundPreference != null) {
        updateData['background_preference'] = backgroundPreference;
      }

      if (sleepCoins != null) {
        updateData['sleep_coins'] = sleepCoins;
      }

      await _supabase.from('users').upsert(
        updateData,
        onConflict: 'id',
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') { // unique_violation
        throw Exception('このユーザー名は既に使用されています。');
      }
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    // With 'ON DELETE CASCADE' set on the foreign key in Supabase,
    // deleting a user will automatically delete all their sleep_records.
    await _supabase.from('users').delete().eq('id', userId);
  }

  // --- Shop Feature Methods ---

  Future<List<String>> getUnlockedBackgrounds(String userId) async {
    try {
      final response = await _supabase
          .from('user_unlocked_backgrounds')
          .select('background_id')
          .eq('user_id', userId);
      return response.map((item) => item['background_id'] as String).toList();
    } catch (e) {
      return []; // Return empty list on error
    }
  }

  Future<void> purchaseBackground({required String userId, required String backgroundId, required int cost}) async {
    await _supabase.rpc('purchase_background', params: {
      'p_user_id': userId,
      'p_background_id': backgroundId,
      'p_cost': cost,
    });
  }
}