import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // Still need Content for prompts

import 'package:sleep_management_app/services/quiz_service.dart';
import 'package:sleep_management_app/models/quiz_models.dart';
import 'package:sleep_management_app/services/generative_model_interface.dart';

/// A fake implementation of IGenerativeModel for testing purposes.
/// Allows setting predetermined responses or exceptions.
class FakeGenerativeModel implements IGenerativeModel {
  String? nextResponseText;
  Exception? nextException;
  List<Iterable<Content>> receivedPrompts = [];

  FakeGenerativeModel({this.nextResponseText, this.nextException});

  @override
  Future<String?> generateContent(Iterable<Content> prompt,
      {List<SafetySetting>? safetySettings,
      GenerationConfig? generationConfig,
      List<Tool>? tools}) {
    receivedPrompts.add(prompt);
    if (nextException != null) {
      return Future.error(nextException!);
    }
    return Future.value(nextResponseText);
  }
}

void main() {
  group('QuizService', () {
    late QuizService quizService;
    late FakeGenerativeModel fakeGenerativeModel;

    setUp(() {
      fakeGenerativeModel = FakeGenerativeModel();
      // QuizService is initialized with the fake model.
      quizService = QuizService(generativeModel: fakeGenerativeModel);
    });

    tearDown(() {
      fakeGenerativeModel.receivedPrompts.clear();
    });

    test('isModelReady returns true if generativeModel is provided', () {
      expect(quizService.isModelReady(), isTrue);
    });

    test('isModelReady returns false if no generativeModel is provided', () {
      // Test when no generativeModel is provided (simulating no API key or adapter issue)
      final newQuizService = QuizService(generativeModel: null); 
      expect(newQuizService.isModelReady(), isFalse);
    });

    group('getDailyQuiz', () {
      test('should return a quiz question on successful generation', () async {
        fakeGenerativeModel.nextResponseText = '今日のクイズ：睡眠不足は次のうちどれに影響しますか？A) 集中力 B) 食欲 C) 両方';
        final question = await quizService.getDailyQuiz();
        expect(question, '今日のクイズ：睡眠不足は次のうちどれに影響しますか？A) 集中力 B) 食欲 C) 両方');
        expect(fakeGenerativeModel.receivedPrompts.length, 1);
        final firstPart = fakeGenerativeModel.receivedPrompts.first.first.parts.first;
        expect((firstPart as TextPart).text, contains('あなたは睡眠に関する知識が豊富な専門家です。'));
      });

      test('should throw an exception on failed generation', () async {
        fakeGenerativeModel.nextException = Exception('API Error');
        expect(() => quizService.getDailyQuiz(), throwsA(isA<Exception>()));
        expect(fakeGenerativeModel.receivedPrompts.length, 1);
      });

      test('should return default message if response text is null', () async {
        fakeGenerativeModel.nextResponseText = null;
        final question = await quizService.getDailyQuiz();
        expect(question, 'クイズの生成に失敗しました。');
      });
    });

    group('submitAnswer', () {
      test('should return correct QuizResult for a correct answer', () async {
        fakeGenerativeModel.nextResponseText = r'''{"isCorrect": true, "explanation": "正しいです。睡眠不足は集中力と食欲の両方に影響します。"}''';
        final result = await quizService.submitAnswer('Question', 'Answer');
        expect(result.isCorrect, isTrue);
        expect(result.explanation, '正しいです。睡眠不足は集中力と食欲の両方に影響します。');
        expect(fakeGenerativeModel.receivedPrompts.length, 1);
        final firstPart = fakeGenerativeModel.receivedPrompts.first.first.parts.first;
        expect((firstPart as TextPart).text, contains('あなたは睡眠の専門家です。以下のクイズとその回答について'));
      });

      test('should return correct QuizResult for an incorrect answer', () async {
        fakeGenerativeModel.nextResponseText = r'''{"isCorrect": false, "explanation": "残念ながら不正解です。睡眠不足は集中力と食欲の両方に影響します。"}''';
        final result = await quizService.submitAnswer('Question', 'Answer');
        expect(result.isCorrect, isFalse);
        expect(result.explanation, '残念ながら不正解です。睡眠不足は集中力と食欲の両方に影響します。');
      });

      test('should throw an exception on API error during submission', () async {
        fakeGenerativeModel.nextException = Exception('API Submission Error');
        // Expecting a generic Exception thrown by QuizService itself
        expect(() => quizService.submitAnswer('Question', 'Answer'), throwsA(isA<Exception>()));
      });

      test('should throw an exception if response text is null during submission', () async {
        fakeGenerativeModel.nextResponseText = null;
        // Expecting a generic Exception thrown by QuizService itself
        expect(() => quizService.submitAnswer('Question', 'Answer'), throwsA(isA<Exception>()));
      });

      test('should handle markdown code block in response text', () async {
        fakeGenerativeModel.nextResponseText = r'''```json
{"isCorrect": true, "explanation": "Correct answer."}
```''';
        final result = await quizService.submitAnswer('Question', 'Answer');
        expect(result.isCorrect, isTrue);
        expect(result.explanation, 'Correct answer.');
      });

      test('should throw exception for malformed JSON response', () async {
        fakeGenerativeModel.nextResponseText = 'Invalid JSON response';
        // Expecting a FormatException thrown by jsonDecode
        expect(() => quizService.submitAnswer('Question', 'Answer'), throwsA(isA<FormatException>()));
      });
    });
  });
}