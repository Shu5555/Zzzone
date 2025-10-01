import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../models/sleep_record.dart';

class AnalysisService {
  // APIキーをアプリ内に直接記述します。非常に危険なため、取り扱いには最大限の注意を払ってください。
  static const String _apiKey = 'AIzaSyDLlZP3_4cZPfGw9sNsEgG0-7G6VLuwLwU';
  static const String _apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  // LLMの応答は時間がかかる可能性があるため、タイムアウトを60秒に設定
  final _timeoutDuration = const Duration(seconds: 60);

  /// 睡眠記録のリストからプロンプト文字列を生成する
  String _createPrompt(List<SleepRecord> records) {
    var dataText = '日付,睡眠時間,スコア(10満点),日中のパフォーマンス,メモ\n';
    for (var r in records) {
      final sleepDate = r.sleepTime.toIso8601String().substring(0, 10);
      final durationHours = r.duration.inHours;
      final durationMins = r.duration.inMinutes.remainder(60);
      final performanceMap = { 1: '悪い', 2: '普通', 3: '良い' };

      dataText += '${sleepDate},';
      dataText += '${durationHours}時間${durationMins}分,';
      dataText += '${r.score},';
      dataText += '${performanceMap[r.performance] ?? '普通'},';
      dataText += '${r.memo ?? ''}\n';
    }

    return '''あなたは優秀な睡眠コンサルタントです。
以下の睡眠記録データを分析し、ユーザーの睡眠習慣に関する総評、良い点、改善点を日本語で提供してください。

# 分析のルール
- 総評は全体的な睡眠の傾向について150字以内で簡潔にまとめてください。
- 良い点は2つ、箇条書きで挙げてください。
- 改善点も2つ、具体的なアクションを箇条書きで挙げてください。

# 睡眠記録データ
$dataText

# 出力形式
以下の厳密なJSON形式で回答してください。説明や前置き、```json ... ```のようなマークダウンは一切含めないでください。
{
  "overall_comment": "ここに総評を記述",
  "positive_points": [
    "ここに良い点を記述",
    "ここに良い点を記述"
  ],
  "improvement_suggestions": [
    "ここに改善提案を記述",
    "ここに改善提案を記述"
  ]
}
''';
  }

  Future<Map<String, dynamic>> fetchSleepAnalysis(List<SleepRecord> records) async {
    try {
      final prompt = _createPrompt(records);

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final jsonResult = jsonDecode(decodedBody);

        if (jsonResult['candidates'] != null && jsonResult['candidates'][0]['content']['parts'][0]['text'] != null) {
          var analysisText = jsonResult['candidates'][0]['content']['parts'][0]['text'] as String;

          // LLMからの応答にMarkdownコードブロックが含まれている場合、それを取り除く
          final regex = RegExp(r"```json\n?([\s\S]*?)\n?```");
          final match = regex.firstMatch(analysisText.trim());
          if (match != null) {
            analysisText = match.group(1)!;
          }

          return jsonDecode(analysisText) as Map<String, dynamic>;
        } else {
          throw Exception('Failed to parse Gemini response format.');
        }
      } else {
        print('Gemini API Error. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to fetch sleep analysis: ${response.statusCode}');
      }
    } on TimeoutException {
      print('Connection to Gemini API timed out.');
      throw Exception('Connection timed out. Please try again.');
    } catch (e) {
      print('Error in fetchSleepAnalysis: $e');
      rethrow;
    }
  }
}