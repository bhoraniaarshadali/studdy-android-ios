import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paper_section_model.dart';
import '../models/generated_question_model.dart';
import 'pdf_extraction_service.dart';
import '../config/app_config.dart';

class PaperGeneratorService {
  static String get _apiKey => AppConfig.kieaApiKey;
  static const String _apiUrl =
      'https://api.kie.ai/gemini/v1/models/gemini-3-flash-v1betamodels:streamGenerateContent';

  // Step 1: Extract text from PDF
  static Future<String> extractTextFromPDF(Uint8List pdfBytes) async {
    try {
      print('PAPER_GEN: Using Syncfusion for local PDF extraction');
      final result = await PdfExtractionService.extractTextWithMetadata(pdfBytes);
      print('PAPER_GEN: Extracted ${result['total_pages']} pages, ${result['total_chars']} chars');
      return result['text'] as String;
    } catch (e) {
      print('PAPER_GEN: Extraction ERROR - $e');
      throw Exception('Failed to extract PDF: $e');
    }
  }

  // Step 2: Generate questions for a section
  static Future<List<GeneratedQuestion>> generateSectionQuestions({
    required String pdfContent,
    required PaperSection section,
    required String paperTitle,
    String pdfType = 'unknown',
  }) async {
    try {
      print(
        'PAPER_GEN: Generating ${section.questionCount} ${section.questionType} questions for ${section.sectionName}',
      );

      final prompt = _buildPrompt(
        pdfContent: pdfContent,
        section: section,
        paperTitle: paperTitle,
        pdfType: pdfType,
      );

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

      // Check for API errors first (Code 402 = Insufficient Credits)
      if (data['code'] != null && data['code'] == 402) {
        print('PAPER_GEN: Insufficient credits - ${data['msg']}');
        throw Exception('AI service credits exhausted. Please contact administrator.');
      }

      if (data['candidates'] == null) {
        print('PAPER_GEN: Unexpected response - ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        throw Exception('AI service unavailable. Please try again.');
      }

      // Robust parsing
      String rawText = '';
      try {
        final candidates = data['candidates'];
        if (candidates.isEmpty) {
          print('PAPER_GEN: No candidates in response');
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
    String pdfType = 'unknown',
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
        pdfType: pdfType,
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

  static String _buildPrompt({
    required String pdfContent,
    required PaperSection section,
    required String paperTitle,
    required String pdfType,
  }) {
    String contextInstruction = '';

    if (pdfType == 'syllabus') {
      contextInstruction = '''
IMPORTANT: This PDF appears to be a SYLLABUS/COURSE OUTLINE.
- DO NOT ask questions about marks, credits, or course structure
- DO NOT ask "What is the weightage of Unit X?"
- DO NOT ask about reference books or textbook names
- INSTEAD: Use the TOPICS listed in the syllabus to generate conceptual questions
- Generate questions about the SUBJECT MATTER of the listed topics
- Assume standard knowledge about those topics
- Example: If syllabus says "Unit 2: Cloud Computing Basics", ask "What is cloud computing?" NOT "What are the marks for Unit 2?"
''';
    } else if (pdfType == 'chapter') {
      contextInstruction = '''
IMPORTANT: This PDF is CHAPTER/STUDY MATERIAL content.
- Generate questions STRICTLY from the content provided
- Use exact facts, figures, definitions from the text
- Include page references where possible
- Questions should test understanding of the actual content
''';
    } else {
      contextInstruction = '''
IMPORTANT: Generate questions based ONLY on the educational content in this PDF.
- Focus on subject matter knowledge
- Avoid questions about document structure or formatting
- If the content is a syllabus/outline, generate questions about the topics mentioned
''';
    }

    return '''
You are a professional exam paper generator for educational institutions.

$contextInstruction

Generate exactly ${section.questionCount} questions for "${section.sectionName}".

STRICT RULES:
1. Questions must test SUBJECT KNOWLEDGE only
2. NO questions about marks, credits, weightage, or course structure
3. NO questions about reference books or authors (unless content is about literature)
4. NO hallucinated facts - only use information from the PDF
5. Question type: ${section.questionType.toUpperCase()}
6. Difficulty: ${section.difficulty}
7. Marks per question: ${section.marksPerQuestion}
8. Every question must have a source reference

${_getQuestionTypeInstructions(section.questionType)}

Return ONLY valid JSON array, NO markdown, NO backticks:
${_getJsonFormat(section.questionType)}

PDF CONTENT:
$pdfContent
''';
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

  // Save paper to Supabase with PDF upload support
  static Future<String> savePaper({
    required String title,
    required int totalMarks,
    required List<PaperSection> sections,
    required List<GeneratedQuestion> questions,
    required String difficulty,
    required String template,
    Uint8List? pdfBytes,
  }) async {
    try {
      final db = Supabase.instance.client;
      String? pdfUrl;

      // Step 1: Upload PDF to Supabase Storage if provided
      if (pdfBytes != null) {
        print('PAPER_SAVE: Uploading PDF to Supabase Storage...');
        final fileName =
            '${title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

        await db.storage.from('exam-papers').uploadBinary(
              fileName,
              pdfBytes,
              fileOptions: const FileOptions(contentType: 'application/pdf'),
            );

        pdfUrl = db.storage.from('exam-papers').getPublicUrl(fileName);

        print('PAPER_SAVE: PDF uploaded successfully: $pdfUrl');
      }

      // Step 2: Save paper metadata to database
      // Check if paper with same title already exists
      final existing = await db
          .from('generated_papers')
          .select('id')
          .eq('title', title)
          .limit(1);

      if (existing.isNotEmpty) {
        print('PAPER_SAVE: Paper already exists, updating instead of inserting');
        // Update existing record
        await db.from('generated_papers').update({
          'questions': questions.map((q) => q.toJson()).toList(),
          'answer_key': questions
              .map((q) => {
                    'question': q.questionText,
                    'answer': q.answer,
                    'marks': q.marks,
                    'section': q.sectionName,
                  })
              .toList(),
          'pdf_url': pdfUrl,
        }).eq('id', existing[0]['id']);
        return pdfUrl ?? '';
      }

      final response = await db
          .from('generated_papers')
          .insert({
            'title': title,
            'total_marks': totalMarks,
            'sections': sections.map((s) => s.toJson()).toList(),
            'questions': questions.map((q) => q.toJson()).toList(),
            'answer_key': questions
                .map((q) => {
                      'question': q.questionText,
                      'answer': q.answer,
                      'marks': q.marks,
                      'section': q.sectionName,
                    })
                .toList(),
            'difficulty': difficulty,
            'template': template,
            'pdf_url': pdfUrl,
          })
          .select()
          .single();

      print('PAPER_SAVE: Paper saved to DB with id: ${response['id']}');
      return pdfUrl ?? '';
    } catch (e) {
      print('PAPER_SAVE: ERROR - $e');
      throw Exception('Failed to save paper: $e');
    }
  }

  // Fetch all generated papers
  static Future<List<Map<String, dynamic>>> getPaperHistory() async {
    try {
      final db = Supabase.instance.client;
      final response = await db
          .from('generated_papers')
          .select(
              'id, title, total_marks, difficulty, template, pdf_url, created_at, sections, questions')
          .order('created_at', ascending: false);

      print('PAPER_HISTORY: Fetched ${response.length} papers');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('PAPER_HISTORY: ERROR - $e');
      throw Exception('Failed to fetch paper history: $e');
    }
  }

  // Delete paper from DB and Storage
  static Future<void> deletePaper(int id, String? pdfUrl) async {
    try {
      final db = Supabase.instance.client;

      // Delete PDF from storage if exists
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        try {
          // Extract filename from URL more robustly
          final uri = Uri.parse(pdfUrl);
          // URL format: .../storage/v1/object/public/exam-papers/FILENAME
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf('exam-papers');

          if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
            final fileName = pathSegments.sublist(bucketIndex + 1).join('/');
            print('PAPER_DELETE: Deleting file from storage: $fileName');

            await db.storage.from('exam-papers').remove([fileName]);

            print('PAPER_DELETE: File deleted from storage successfully');
          } else {
            print('PAPER_DELETE: Could not extract filename from URL: $pdfUrl');
          }
        } catch (storageError) {
          print(
              'PAPER_DELETE: Storage deletion failed (continuing): $storageError');
          // Continue with DB deletion even if storage deletion fails
        }
      }

      // Always delete from database
      await db.from('generated_papers').delete().eq('id', id);
      print('PAPER_DELETE: Paper deleted from DB: $id');
    } catch (e) {
      print('PAPER_DELETE: ERROR - $e');
      throw Exception('Failed to delete paper: $e');
    }
  }
}
