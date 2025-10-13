import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/sleep_record.dart';

class AnalysisService {
  static final String _apiKey = const String.fromEnvironment('GEMINI_API_KEY');
  static const String _apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent';

  final _timeoutDuration = const Duration(seconds: 60);

  Future<String> _createPrompt(List<SleepRecord> records, String aiTone, String aiGender) async {
    var dataText = '日付,睡眠時間,スコア(10満点),日中のパフォーマンス,昼間の眠気,二度寝,メモ\n';
    for (var r in records) {
      final sleepDate = r.sleepTime.toIso8601String().substring(0, 10);
      final durationHours = r.duration.inHours;
      final durationMins = r.duration.inMinutes.remainder(60);
      final performanceMap = { 1: '悪い', 2: '普通', 3: '良い' };
      final hadDrowsiness = r.hadDaytimeDrowsiness ? 'あり' : 'なし';
      final didOversleep = r.didNotOversleep ? 'なし' : 'あり';

      dataText += '${sleepDate},';
      dataText += '${durationHours}時間${durationMins}分,';
      dataText += '${r.score},';
      dataText += '${performanceMap[r.performance] ?? '普通'},';
      dataText += '$hadDrowsiness,';
      dataText += '$didOversleep,';
      dataText += '${r.memo ?? ''}\n';
    }

    final jsonString = await rootBundle.loadString('assets/persona_definitions.json');
    final toneInstructions = json.decode(jsonString);

    final instruction = toneInstructions[aiTone] ?? toneInstructions['default']!;
    String genderInstruction = '';
    if (aiGender == 'male') {
      genderInstruction = 'また、回答の相手は男性です。';
    } else if (aiGender == 'female') {
      genderInstruction = 'また、回答の相手は女性です。';
    }

    return '''$instruction
$genderInstruction
以下の睡眠記録データを分析し、ユーザーの睡眠習慣に関する総評、良い点、改善点を日本語で提供してください。
「昼間の眠気」や「二度寝」の項目も考慮して、もし問題が見られる場合は、その原因と対策についても言及してください。

# 分析のルール
- 総評は全体的な睡眠の傾向について150字程度で簡潔にまとめてください。
- 良い点は、重要なものから2〜4つ、箇条書きで挙げてください。
- 改善点も、具体的なアクションを2〜4つ、箇条書きで挙げてください。

# 睡眠記録データ
$dataText

# 出力形式
以下の厳密なJSON形式で回答してください。説明や前置き、```json ... ```のようなマークダウンは一切含めないでください。
{
  "overall_comment": "ここに総評を記述",
  "positive_points": [
    "ここに良い点を記述",
    "ここに良い点を記述",
    "（あれば）ここに良い点を記述",
    "（あれば）ここに良い点を記述"
  ],
  "improvement_suggestions": [
    "ここに改善提案を記述",
    "ここに改善提案を記述",
    "（あれば）ここに改善提案を記述",
    "（あれば）ここに改善提案を記述"
  ]
}
''';
  }

  Future<Map<String, dynamic>> fetchSleepAnalysis(List<SleepRecord> records, String aiTone, String aiGender) async {
    try {
      final prompt = await _createPrompt(records, aiTone, aiGender);

      final response = await http.post(
        Uri.parse(_apiEndpoint),
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
