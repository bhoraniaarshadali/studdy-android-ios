import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';
import '../config/app_config.dart';

class KieAiService {
  static const String _baseUrl = 'https://api.kie.ai/gemini/v1/models/gemini-3-flash-v1betamodels:streamGenerateContent';
  static String get _apiKey => AppConfig.kieaApiKey;

  static Future<List<QuestionModel>> generateQuestions({
    required String content,
    required int questionCount,
    required int optionCount,
    required String difficulty,
  }) async {
    final prompt = 'Generate exactly $questionCount MCQ questions from the following content. Each question must have exactly $optionCount options. Difficulty: $difficulty. Return ONLY a valid JSON array, no extra text, no markdown, no backticks. Format: [{"question": "...", "options": ["A", "B", "C", "D"], "correct": 0}] where correct is 0-based index. Content: $content';
    
    debugPrint('KieAI: Sending request - questions: $questionCount, options: $optionCount, difficulty: $difficulty');
    
    final requestBody = {
      "stream": false,
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {}
    };
    debugPrint('KieAI: Request body: ${json.encode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('KieAI: Response status: ${response.statusCode}');
      debugPrint('KieAI: Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        String textResponse = data['candidates'][0]['content']['parts'][0]['text'];
        debugPrint('KieAI: Extracted text: $textResponse');

        // Clean JSON response (remove markdown backticks if present)
        String cleanedText = textResponse.replaceAll('```json', '').replaceAll('```', '').trim();
        debugPrint('KieAI: Cleaned text: $cleanedText');

        final List<dynamic> questionList = jsonDecode(cleanedText);

        final questions = List.generate(questionList.length, (index) {
          final item = questionList[index];
          return QuestionModel(
            id: index.toString(),
            questionText: item['question'],
            options: List<String>.from(item['options']),
            correctIndex: item['correct'],
          );
        });

        debugPrint('KieAI: Successfully parsed ${questions.length} questions');
        return questions;
      } else {
        throw Exception('Failed to generate questions: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('KieAI: ERROR - $e');
      throw Exception('Error occurred while generating questions: $e');
    }
  }
}
