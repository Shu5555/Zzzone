import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // TimeoutExceptionのため

class ApiService {
  final String _baseUrl = 'https://zzzone.netlify.app/.netlify/functions';
  final _timeoutDuration = const Duration(seconds: 10);

  /// ユーザー情報を更新または作成する
  Future<void> updateUser(String id, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'username': username}),
      ).timeout(_timeoutDuration);

      if (response.statusCode != 200) {
        // エラーハンドリングを強化
        throw Exception('Failed to update user: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } catch (e) {
      // 呼び出し元で処理できるように再スロー
      rethrow;
    }
  }

  /// 睡眠記録を送信する
  Future<void> submitRecord(String userId, int sleepDuration, String date) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/submit-record'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'sleep_duration': sleepDuration,
          'date': date,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode != 201) {
        throw Exception('Failed to submit record: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } catch (e) {
      rethrow;
    }
  }

  /// ランキングデータを取得する
  Future<List<Map<String, dynamic>>> getRanking(String date) async {
    try {
      final uri = Uri.parse('$_baseUrl/get-ranking?date=$date');
      final response = await http.get(uri).timeout(_timeoutDuration);
      if (response.statusCode == 200) {
        // UTF-8でデコードしてからJSONをパースする
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        // エラー時は空リストではなく例外をスロー
        throw Exception('Failed to get ranking: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } catch (e) {
      rethrow;
    }
  }
}