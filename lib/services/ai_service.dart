import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';

class AiService {
  static const String _apiKey = 'AIzaSyB3uw4T7iRHl81a2-Pibr-7e175-u6nQ6w';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey';

  static Future<List<QuestionModel>> generateQuestions({
    required String content,
    required int questionCount,
    required int optionCount,
    required String difficulty,
  }) async {
    final prompt = """
Generate exactly $questionCount MCQ questions from the following content.
Each question must have exactly $optionCount options.
Difficulty: $difficulty
Return ONLY a valid JSON array, no extra text, no markdown, no backticks.
Format:
[{"question": "...", "options": ["A", "B", "C", "D"], "correct": 0}]
correct is 0-based index of correct answer.
Content: $content
""";

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        String textResponse = data['candidates'][0]['content']['parts'][0]['text'];

        // Clean JSON response (remove markdown backticks if present)
        textResponse = textResponse.replaceAll('```json', '').replaceAll('```', '').trim();

        final List<dynamic> questionList = jsonDecode(textResponse);

        return List.generate(questionList.length, (index) {
          final item = questionList[index];
          return QuestionModel(
            id: index.toString(),
            questionText: item['question'],
            options: List<String>.from(item['options']),
            correctIndex: item['correct'],
          );
        });
      } else {
        throw Exception('Failed to generate questions: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error occurred while generating questions: $e');
    }
  }
}
