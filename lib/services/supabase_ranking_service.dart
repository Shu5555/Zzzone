import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../utils/date_helper.dart'; // New import

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

  Future<List<Map<String, dynamic>>> getRankingWithQuotes({String? date}) async {
    final targetDate = date ?? getLogicalDateInJST();
    final response = await _supabase.rpc('get_daily_ranking_with_quotes', params: {'p_date': targetDate});
    return (response as List).map((item) => item as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*, favorite_quote_id, ultra_rare_tickets, ai_tone, ai_gender_preference') // Add ai_gender_preference
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

  Future<void> updateUserAiTone({required String userId, required String aiTone}) async {
    await _supabase.from('users').update({'ai_tone': aiTone}).eq('id', userId);
  }

  Future<void> updateUserAiGender({required String userId, required String aiGender}) async {
    await _supabase.from('users').update({'ai_gender_preference': aiGender}).eq('id', userId);
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

  // --- Gacha Feature Methods (New Architecture) ---

  /// Deducts coins for a gacha pull and awards gacha points.
  Future<void> deductCoinsForGacha(String userId, int cost, int pullCount) async {
    await _supabase.rpc('deduct_coins_for_gacha', params: {
      'p_user_id': userId,
      'p_cost': cost,
      'p_pull_count': pullCount,
    });
  }

  /// Purchases a gacha ticket using gacha points.
  Future<void> purchaseGachaTicket({required String userId, required int cost, required String ticketType}) async {
    await _supabase.rpc('purchase_gacha_ticket', params: {
      'p_user_id': userId,
      'p_cost': cost,
      'p_ticket_type': ticketType, // Currently unused in SQL, but good for future expansion
    });
  }

  /// Consumes an ultra rare gacha ticket.
  Future<void> consumeUltraRareTicket(String userId) async {
    await _supabase.rpc('consume_ultra_rare_ticket', params: {
      'p_user_id': userId,
    });
  }

  /// Sets the user's favorite quote to be displayed on the home screen.
  Future<void> setFavoriteQuote(String userId, String? quoteId) async {
    await _supabase.from('users').update({'favorite_quote_id': quoteId}).eq('id', userId);
  }

  /// Updates the user's sleep coins by adding a specified amount.
  Future<void> updateSleepCoins({required String userId, required int coinsToAdd}) async {
    await _supabase.rpc('update_sleep_coins', params: {
      'p_user_id': userId,
      'p_coins_to_add': coinsToAdd,
    });
  }

  /// Fetches the AI score ranking from Supabase.
  Future<List<Map<String, dynamic>>> getAiScoreRanking() async {
    try {
      final response = await _supabase.rpc('get_ai_score_ranking');
      return (response as List).map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching AI score ranking: $e');
      return [];
    }
  }
}
