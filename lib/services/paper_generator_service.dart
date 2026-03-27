import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paper_section_model.dart';
import '../models/generated_question_model.dart';

class PaperGeneratorService {
  static const String _apiKey = '9c30f9d7b3eab8e83e6f5c7fbaa3cbb7';
  static const String _apiUrl =
      'https://api.kie.ai/gemini/v1/models/gemini-3-flash-v1betamodels:streamGenerateContent';

  // Step 1: Extract text from PDF
  static Future<String> extractTextFromPDF(Uint8List pdfBytes) async {
    try {
      print('PAPER_GEN: Extracting text from PDF (${pdfBytes.length} bytes)');
      final base64Pdf = base64Encode(pdfBytes);

      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'stream': false,
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'inline_data': {
                    'mime_type': 'application/pdf',
                    'data': base64Pdf,
                  },
                },
                {
                  'text':
                      'Extract ALL text content from this PDF completely and accurately. Return only the plain text with page numbers indicated like [Page 1], [Page 2] etc. Do not summarize - extract everything word by word.',
                },
              ],
            },
          ],
        }),
      )
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('PAPER_GEN: Extraction timed out');
          throw Exception('PDF extraction timed out after 60 seconds');
        },
      );

      final data = json.decode(response.body);
      String text = '';

      // Robust parsing
      try {
        final candidates = data['candidates'];
        if (candidates == null || candidates.isEmpty) {
          throw Exception('No candidates in API response');
        }
        text = candidates[0]['content']['parts'][0]['text'] as String;
      } catch (e) {
        print('PAPER_GEN: Extraction parse error: $e');
        print('PAPER_GEN: Response: ${response.body}');
        throw Exception('Failed to parse extraction response');
      }

      print('PAPER_GEN: Extracted ${text.length} characters from PDF');
      return text;
    } catch (e) {
      print('PAPER_GEN: PDF extraction ERROR - $e');
      throw Exception('Failed to extract PDF content: $e');
    }
  }

  // Step 2: Generate questions for a section
  static Future<List<GeneratedQuestion>> generateSectionQuestions({
    required String pdfContent,
    required PaperSection section,
    required String paperTitle,
  }) async {
    try {
      print(
        'PAPER_GEN: Generating ${section.questionCount} ${section.questionType} questions for ${section.sectionName}',
      );

      final questionTypeInstructions = _getQuestionTypeInstructions(
        section.questionType,
      );

      final prompt =
          '''
You are a strict exam paper generator. Generate exactly ${section.questionCount} questions for "${section.sectionName}".

STRICT RULES - FOLLOW EXACTLY:
1. Questions MUST come ONLY from the provided PDF content below
2. Do NOT invent any facts, figures, or information not in the PDF
3. If content is insufficient, generate fewer questions
4. Every question must have a source reference (mention which part of PDF)
5. Question type: ${section.questionType.toUpperCase()}
6. Difficulty: ${section.difficulty}
7. Marks per question: ${section.marksPerQuestion}

${questionTypeInstructions}

Return ONLY a valid JSON array with NO extra text, NO markdown, NO backticks:
${_getJsonFormat(section.questionType)}

PDF CONTENT (use ONLY this):
$pdfContent
''';

      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'stream': false,
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      )
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('PAPER_GEN: API call timed out after 60 seconds');
          throw Exception('API request timed out. Please try again.');
        },
      );

      final data = json.decode(response.body);

      // Robust parsing
      String rawText = '';
      try {
        final candidates = data['candidates'];
        if (candidates == null || candidates.isEmpty) {
          print('PAPER_GEN: No candidates in response');
          print(
            'PAPER_GEN: Full response: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
          );
          throw Exception('No candidates in API response');
        }
        final content = candidates[0]['content'];
        if (content == null) {
          print('PAPER_GEN: Content is null in response');
          throw Exception('Content is null in API response');
        }
        final parts = content['parts'];
        if (parts == null || parts.isEmpty) {
          print('PAPER_GEN: Parts is null or empty');
          throw Exception('Parts is null in API response');
        }
        rawText = parts[0]['text'] as String;
        print('PAPER_GEN: Raw text length: ${rawText.length}');
      } catch (e) {
        print('PAPER_GEN: Parse error: $e');
        print('PAPER_GEN: Response status: ${response.statusCode}');
        print(
          'PAPER_GEN: Response body: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}',
        );
        rethrow;
      }

      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      print(
        'PAPER_GEN: Raw response preview: ${rawText.substring(0, rawText.length > 200 ? 200 : rawText.length)}',
      );

      final List<dynamic> questionsJson = json.decode(rawText);
      final questions = questionsJson
          .map(
            (q) => GeneratedQuestion(
              questionText: q['question'] ?? '',
              questionType: section.questionType,
              options: q['options'] != null
                  ? List<String>.from(q['options'])
                  : null,
              answer: q['answer'] ?? '',
              marks: section.marksPerQuestion,
              difficulty: section.difficulty,
              sectionName: section.sectionName,
              sourceReference: q['source_reference'] ?? 'From uploaded PDF',
              confidenceScore: (q['confidence_score'] ?? 0.8).toDouble(),
            ),
          )
          .toList();

      print(
          'PAPER_GEN: Generated ${questions.length} questions for ${section.sectionName}');
      return questions;
    } catch (e) {
      print('PAPER_GEN: Section generation ERROR - $e');
      throw Exception(
        'Failed to generate questions for ${section.sectionName}: $e',
      );
    }
  }

  // Generate full paper with all sections
  static Future<List<GeneratedQuestion>> generateFullPaper({
    required String pdfContent,
    required List<PaperSection> sections,
    required String paperTitle,
    required String overallDifficulty,
    void Function(String status, int current, int total)? onProgress,
  }) async {
    final List<GeneratedQuestion> allQuestions = [];

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      onProgress?.call(
        'Generating ${section.sectionName}...',
        i + 1,
        sections.length,
      );
      print(
        'PAPER_GEN: Processing section ${i + 1}/${sections.length}: ${section.sectionName}',
      );

      final questions = await generateSectionQuestions(
        pdfContent: pdfContent,
        section: section,
        paperTitle: paperTitle,
      );
      allQuestions.addAll(questions);

      // Small delay between sections to avoid rate limits
      await Future.delayed(const Duration(seconds: 2));
    }

    print(
      'PAPER_GEN: Full paper generated - total questions: ${allQuestions.length}',
    );
    return allQuestions;
  }

  static String _getQuestionTypeInstructions(String type) {
    switch (type) {
      case 'mcq':
        return 'Generate MCQ questions with exactly 4 options (A, B, C, D). One correct answer.';
      case 'short':
        return 'Generate short answer questions. Answer should be 2-3 sentences max.';
      case 'long':
        return 'Generate long answer/essay questions. Answer should be detailed, 5-8 sentences.';
      case 'true_false':
        return 'Generate True/False questions. Answer must be exactly "True" or "False".';
      case 'fill_blank':
        return 'Generate fill in the blank questions. Use "______" for the blank. Answer is the word/phrase that fills the blank.';
      default:
        return 'Generate questions appropriate for the topic.';
    }
  }

  static String _getJsonFormat(String type) {
    if (type == 'mcq') {
      return '''[
  {
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": "Option A",
    "source_reference": "Page 1, paragraph about topic X",
    "confidence_score": 0.9
  }
]''';
    }
    return '''[
  {
    "question": "Question text here?",
    "answer": "Answer text here",
    "source_reference": "Page 1, paragraph about topic X",
    "confidence_score": 0.9
  }
]''';
  }

  // Save paper to Supabase
  static Future<void> savePaper({
    required String title,
    required int totalMarks,
    required List<PaperSection> sections,
    required List<GeneratedQuestion> questions,
    required String difficulty,
    required String template,
  }) async {
    try {
      final db = Supabase.instance.client;

      await db.from('generated_papers').insert({
        'title': title,
        'total_marks': totalMarks,
        'sections': sections.map((s) => s.toJson()).toList(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'answer_key': questions
            .map(
              (q) => {
                'question': q.questionText,
                'answer': q.answer,
                'marks': q.marks,
                'section': q.sectionName,
              },
            )
            .toList(),
        'difficulty': difficulty,
        'template': template,
      });

      print('PAPER_GEN: Paper saved to Supabase successfully');
    } catch (e) {
      print('PAPER_GEN: Save ERROR - $e');
      throw Exception('Failed to save paper: $e');
    }
  }
}
