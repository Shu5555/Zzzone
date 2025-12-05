import 'package:google_generative_ai/google_generative_ai.dart';
import 'generative_model_interface.dart';

/// Adapter class to wrap the concrete GenerativeModel and implement IGenerativeModel.
class GenerativeModelAdapter implements IGenerativeModel {
  final GenerativeModel _generativeModel;

  GenerativeModelAdapter(this._generativeModel);

  @override
  Future<String?> generateContent(Iterable<Content> prompt,
      {List<SafetySetting>? safetySettings,
      GenerationConfig? generationConfig,
      List<Tool>? tools}) async { // Added async keyword here
    final response = await _generativeModel.generateContent(
      prompt,
      safetySettings: safetySettings,
      generationConfig: generationConfig,
      tools: tools,
    );
    return response.text;
  }
}
