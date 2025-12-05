import 'package:google_generative_ai/google_generative_ai.dart';

/// Abstract interface for a generative model.
/// This allows for easy mocking/faking of the GenerativeModel in tests.
abstract class IGenerativeModel {
  Future<String?> generateContent(Iterable<Content> prompt,
      {List<SafetySetting>? safetySettings,
      GenerationConfig? generationConfig,
      List<Tool>? tools});
}
