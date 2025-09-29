import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String _baseUrl = 'https://zzzone.netlify.app/.netlify/functions';

  /// ユーザー情報を更新または作成する
  Future<void> updateUser(String id, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'username': username}),
      );
      if (response.statusCode != 200) {
        // エラーハンドリング（例: ログ出力）
        print('Failed to update user: ${response.body}');
      }
    } catch (e) {
      print('Error calling updateUser: $e');
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
      );
      if (response.statusCode != 201) {
        print('Failed to submit record: ${response.body}');
      }
    } catch (e) {
      print('Error calling submitRecord: $e');
    }
  }

  /// ランキングデータを取得する
  Future<List<Map<String, dynamic>>> getRanking() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/get-ranking'));
      if (response.statusCode == 200) {
        // UTF-8でデコードしてからJSONをパースする
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        print('Failed to get ranking: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error calling getRanking: $e');
      return [];
    }
  }
}
