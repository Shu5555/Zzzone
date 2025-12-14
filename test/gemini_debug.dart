import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  // Load .env manually
  final envFile = File('assets/.env');
  if (!envFile.existsSync()) {
    print('assets/.env not found');
    return;
  }

  String? apiKey;
  final lines = await envFile.readAsLines();
  for (final line in lines) {
    if (line.startsWith('GEMINI_API_KEY=')) {
      apiKey = line.split('=')[1].trim();
      break;
    }
  }

  if (apiKey == null || apiKey.isEmpty) {
    print('GEMINI_API_KEY NOT found in assets/env');
    return;
  }
  
  print('API Key found: ${apiKey.substring(0, 4)}...');

  // Test Analysis Service Endpoint (gemini-2.5-flash)
  final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  print('Testing endpoint: $endpoint');

  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Hello, tell me a joke.'}
            ]
          }
        ]
      }),
    );

    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');
  } catch (e) {
    print('Error calling API: $e');
  }
}
