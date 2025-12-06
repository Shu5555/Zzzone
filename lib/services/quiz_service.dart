import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/quiz_models.dart';
import 'generative_model_interface.dart';
import 'generative_model_adapter.dart';

class QuizService {
  final IGenerativeModel? _generativeModel;

  QuizService({IGenerativeModel? generativeModel})
      : _generativeModel = generativeModel ??
            (_getApiKey() != null
                ? GenerativeModelAdapter(
                    GenerativeModel(
                        model: 'gemini-2.5-flash', apiKey: _getApiKey()!))
                : null);

  static String? _getApiKey() {
    if (kDebugMode) {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      return apiKey.isEmpty ? null : apiKey;
    } else {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      return apiKey.isEmpty ? null : apiKey;
    }
  }

  // Renamed from isAvailable to reflect constructor logic
  bool isModelReady() {
    return _generativeModel != null;
  }


  Future<String> getDailyQuiz() async {
    if (!isModelReady()) {
      throw Exception('AIモデルが準備できていません。APIキーが設定されているか確認してください。');
    }

    try {
      final prompt = [
        Content.text(
          'あなたは睡眠に関する知識が豊富な専門家です。'
          'ユーザーの睡眠改善に役立つ、面白くてためになるクイズを1問だけ作成してください。'
          '形式は問題文のみのシンプルなテキストで、選択肢は含めないでください'
          'また、毎日違う問題になるように、以下の日付情報を考慮してください。\n'
          '今日の日付: ${DateTime.now().toIso8601String()}'
        )
      ];
      final quizQuestion = await _generativeModel!.generateContent(prompt);
      return quizQuestion ?? 'クイズの生成に失敗しました。';
    } catch (e) {
      // ignore: avoid_print
      print('クイズの生成中にエラーが発生しました: $e');
      throw Exception('クイズの取得に失敗しました。');
    }
  }

  Future<QuizResult> submitAnswer(String question, String answer) async {
    if (!isModelReady()) {
      throw Exception('AIモデルが準備できていません。APIキーが設定されているか確認してください。');
    }

    try {
      final prompt = [
        Content.text(
            'あなたは睡眠の専門家です。以下のクイズとその回答について、正解かどうかを判定し、解説を生成してください。\n'
            '回答は必ず以下のJSON形式で返してください:\n'
            '{"isCorrect": boolean, "explanation": "string"}\n\n'
            '## クイズ問題:\n'
            '$question\n\n'
            '## ユーザーの回答:\n'
            '$answer')
      ];

      final responseText = await _generativeModel!.generateContent(prompt);

      if (responseText == null) {
        throw Exception('AIからの有効な応答がありませんでした。');
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
