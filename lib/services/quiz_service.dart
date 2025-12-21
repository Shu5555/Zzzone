import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz_models.dart';

class QuizService {
  static String? _getApiKey() {
    // Web版ではAPIキーを使用しない（Edge Function経由でアクセス）
    if (kIsWeb) {
      return null;
    }
    
    if (kDebugMode) {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      return apiKey.isEmpty ? null : apiKey;
    } else {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      return apiKey.isEmpty ? null : apiKey;
    }
  }

  // Web版では常にtrue（Edge Function経由で利用可能）
  // モバイル版ではAPIキーがあればtrue
  bool isModelReady() {
    return kIsWeb || _getApiKey() != null;
  }

  Future<String> getDailyQuiz() async {
    if (!isModelReady() && !kIsWeb) {
      throw Exception('AIモデルが準備できていません。APIキーが設定されているか確認してください。');
    }

    try {
      final prompt = 
          'あなたは睡眠に関する知識が豊富な専門家です。'
          'ユーザーの睡眠改善に役立つ、面白くてためになるクイズを1問だけ作成してください。'
          '形式は問題文のみのシンプルなテキストで、選択肢は含めないでください'
          'ただし、複数回答を求めず、回答が1つだけであることを確認してください'
          'また、毎日違う問題になるように、以下の日付情報を考慮してください。\n'
          '今日の日付: ${DateTime.now().toIso8601String()}';
      
      String responseText;

      if (kIsWeb) {
        // Web版: Supabase Edge Function経由で呼び出し
        final supabaseUrl = kDebugMode
            ? (dotenv.env['SUPABASE_URL'] ?? '')
            : const String.fromEnvironment('SUPABASE_URL');
        final supabaseAnonKey = kDebugMode
            ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '')
            : const String.fromEnvironment('SUPABASE_ANON_KEY');
        // 末尾のスラッシュを削除して二重スラッシュを防ぐ
        final baseUrl = supabaseUrl.endsWith('/') ? supabaseUrl.substring(0, supabaseUrl.length - 1) : supabaseUrl;
        final edgeFunctionUrl = '$baseUrl/functions/v1/gemini-proxy';

        final response = await http.post(
          Uri.parse(edgeFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $supabaseAnonKey',
          },
          body: jsonEncode({
            'prompt': prompt,
            'modelType': 'flash',
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('クイズの生成に失敗しました: ${response.statusCode}');
        }

        final jsonResult = jsonDecode(response.body);
        responseText = jsonResult['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        // モバイル版: 直接Gemini APIを呼び出し
        final apiKey = _getApiKey()!;
        final apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

        final response = await http.post(
          Uri.parse(apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-goog-api-key': apiKey,
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
        );

        if (response.statusCode != 200) {
          throw Exception('クイズの生成に失敗しました: ${response.statusCode}');
        }

        final jsonResult = jsonDecode(response.body);
        responseText = jsonResult['candidates'][0]['content']['parts'][0]['text'] as String;
      }

      return responseText;
    } catch (e) {
      // ignore: avoid_print
      print('クイズの生成中にエラーが発生しました: $e');
      throw Exception('クイズの取得に失敗しました。');
    }
  }

  Future<QuizResult> submitAnswer(String question, String answer) async {
    if (!isModelReady() && !kIsWeb) {
      throw Exception('AIモデルが準備できていません。APIキーが設定されているか確認してください。');
    }

    try {
      final prompt = 
          'あなたは睡眠の専門家です。以下のクイズとその回答について、正解かどうかを判定し、解説を生成してください。\n'
          '回答は必ず以下のJSON形式で返してください:\n'
          '{"isCorrect": boolean, "explanation": "string"}\n\n'
          '## クイズ問題:\n'
          '$question\n\n'
          '## ユーザーの回答:\n'
          '$answer';

      String responseText;

      if (kIsWeb) {
        // Web版: Supabase Edge Function経由で呼び出し
        final supabaseUrl = kDebugMode
            ? (dotenv.env['SUPABASE_URL'] ?? '')
            : const String.fromEnvironment('SUPABASE_URL');
        final supabaseAnonKey = kDebugMode
            ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '')
            : const String.fromEnvironment('SUPABASE_ANON_KEY');
        // 末尾のスラッシュを削除して二重スラッシュを防ぐ
        final baseUrl = supabaseUrl.endsWith('/') ? supabaseUrl.substring(0, supabaseUrl.length - 1) : supabaseUrl;
        final edgeFunctionUrl = '$baseUrl/functions/v1/gemini-proxy';

        final response = await http.post(
          Uri.parse(edgeFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $supabaseAnonKey',
          },
          body: jsonEncode({
            'prompt': prompt,
            'modelType': 'flash',
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('回答の送信に失敗しました: ${response.statusCode}');
        }

        final jsonResult = jsonDecode(response.body);
        responseText = jsonResult['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        // モバイル版: 直接Gemini APIを呼び出し
        final apiKey = _getApiKey()!;
        final apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

        final response = await http.post(
          Uri.parse(apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-goog-api-key': apiKey,
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
        );

        if (response.statusCode != 200) {
          throw Exception('回答の送信に失敗しました: ${response.statusCode}');
        }

        final jsonResult = jsonDecode(response.body);
        responseText = jsonResult['candidates'][0]['content']['parts'][0]['text'] as String;
      }

      // AIからの応答がマークダウンのコードブロックを含む場合があるため、それを除去する
      final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      return QuizResult.fromJson(decoded);

    } catch (e) {
      // ignore: avoid_print
      print('回答の送信中にエラーが発生しました: $e');
      throw Exception('回答の処理に失敗しました。');
    }
  }
}
