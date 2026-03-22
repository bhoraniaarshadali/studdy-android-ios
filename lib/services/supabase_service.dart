import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_model.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // Generate random 6 digit exam code
  static String generateExamCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Save exam to Supabase
  static Future<String> publishExam({
    required String title,
    required List<QuestionModel> questions,
    required String resultMode, // 'instant' or 'manual'
    required String timerMode, // 'none', 'duration', 'window'
    int? durationMinutes,
    DateTime? windowStart,
    DateTime? windowEnd,
  }) async {
    debugPrint('PUBLISH: Starting publish process');
    debugPrint('PUBLISH: Title: $title');
    debugPrint('PUBLISH: Timer: $timerMode ($durationMinutes min)');
    try {
      final code = generateExamCode();
      debugPrint('PUBLISH: Generated code: $code');
      
      final questionsJson = questions.map((q) => q.toJson()).toList();
      
      print('PUBLISH: Timer mode: $timerMode');
      if (timerMode == 'duration') print('PUBLISH: Duration: $durationMinutes minutes');
      if (timerMode == 'window') print('PUBLISH: Window: $windowStart to $windowEnd');

      debugPrint('PUBLISH: Sending to Supabase...');
      await _client.from('exams').insert({
        'code': code,
        'title': title,
        'questions': questionsJson,
        'result_mode': resultMode,
        'results_published': false,
        'timer_mode': timerMode,
        'duration_minutes': durationMinutes,
        'window_start': windowStart?.toUtc().toIso8601String(),
        'window_end': windowEnd?.toUtc().toIso8601String(),
      });
      
      debugPrint('PUBLISH: Success! Exam saved with code: $code');
      return code;
    } catch (e) {
      debugPrint('PUBLISH: ERROR - $e');
      throw Exception('Failed to publish exam: $e');
    }
  }

  // Get all exams for teacher
  static Future<List<Map<String, dynamic>>> getTeacherExams() async {
    try {
      // 1. First fetch all exams:
      final List<dynamic> exams = await _client
        .from('exams')
        .select('id, code, title, result_mode, results_published, created_at')
        .order('created_at', ascending: false);
      
      print('TEACHER_EXAMS: Got ${exams.length} exams');

      final List<Map<String, dynamic>> examList = List<Map<String, dynamic>>.from(exams);

      // 2. For each exam, separately fetch student count:
      for (var exam in examList) {
        final results = await _client
          .from('results')
          .select('id')
          .eq('exam_code', exam['code']);
        
        exam['student_count'] = results.length;
        print('TEACHER_EXAMS: Exam ${exam['code']} has ${results.length} students');
      }

      // 3. Return the exams list with student_count added
      return examList;
    } catch (e) {
      print('TEACHER_EXAMS: ERROR - $e');
      throw Exception('Failed to fetch exams: $e');
    }
  }

  // Publish results for an exam
  static Future<void> publishResults(String examCode) async {
    try {
      debugPrint('PUBLISH_RESULTS: Publishing results for exam: $examCode');
      await _client
          .from('exams')
          .update({'results_published': true})
          .eq('code', examCode);
      debugPrint('PUBLISH_RESULTS: Results published for exam: $examCode');
    } catch (e) {
      debugPrint('PUBLISH_RESULTS: ERROR - $e');
      throw Exception('Failed to publish results: $e');
    }
  }

  // Get results for a specific exam
  static Future<List<Map<String, dynamic>>> getExamResults(String examCode) async {
    try {
      debugPrint('EXAM_RESULTS: Fetching results for $examCode');
      final results = await _client
          .from('results')
          .select()
          .eq('exam_code', examCode)
          .order('score', ascending: false);
      
      debugPrint('EXAM_RESULTS: Fetched ${(results as List).length} results for $examCode');
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      debugPrint('EXAM_RESULTS: ERROR - $e');
      throw Exception('Failed to fetch results: $e');
    }
  }

  // Get results for a specific student by enrollment with exam details
  static Future<List<Map<String, dynamic>>> getStudentResults(String enrollmentNumber) async {
    try {
      debugPrint('STUDENT_RESULTS: Fetching for $enrollmentNumber');
      final List<dynamic> resultsRaw = await _client
          .from('results')
          .select()
          .eq('enrollment_number', enrollmentNumber)
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> enrichedResults = [];
      
      for (var res in resultsRaw) {
        final Map<String, dynamic> result = Map<String, dynamic>.from(res);
        try {
          // Fetch exam details for this result
          final examResponse = await _client
              .from('exams')
              .select('title, result_mode, results_published')
              .eq('code', result['exam_code'])
              .single();
          
          result['exam_title'] = examResponse['title'];
          result['result_mode'] = examResponse['result_mode'];
          result['results_published'] = examResponse['results_published'];
        } catch (e) {
          debugPrint('STUDENT_RESULTS: Could not fetch exam details for ${result['exam_code']}');
          result['exam_title'] = 'Unknown Exam';
        }
        enrichedResults.add(result);
      }
      
      print('STUDENT_RESULTS: Enriched ${enrichedResults.length} results with exam data');
      return enrichedResults;
    } catch (e) {
      debugPrint('STUDENT_RESULTS: ERROR - $e');
      throw Exception('Failed to fetch student results: $e');
    }
  }

  // Check if student exists or create new one
  static Future<Map<String, dynamic>> checkOrCreateStudent(String enrollmentNumber) async {
    try {
      // 1. Check if exists
      final response = await _client
          .from('students')
          .select()
          .eq('enrollment_number', enrollmentNumber)
          .single();
      
      print('STUDENT: Existing student found: $enrollmentNumber');
      return {'isNew': false, 'student': response};
    } catch (e) {
      // 2. Student not found, create new
      try {
        print('STUDENT: Student not found, creating new: $enrollmentNumber');
        final newStudent = await _client
            .from('students')
            .insert({'enrollment_number': enrollmentNumber})
            .select()
            .single();
        
        print('STUDENT: New student created: $enrollmentNumber');
        return {'isNew': true, 'student': newStudent};
      } catch (insertError) {
        print('STUDENT: Create ERROR - $insertError');
        throw Exception('Failed to create student: $insertError');
      }
    }
  }

  // Get student info by enrollment
  static Future<Map<String, dynamic>?> getStudentByEnrollment(String enrollmentNumber) async {
    try {
      final response = await _client
          .from('students')
          .select()
          .eq('enrollment_number', enrollmentNumber)
          .single();
      
      print('STUDENT: Fetched student: $enrollmentNumber');
      return response;
    } catch (e) {
      print('STUDENT: Fetch ERROR - $e');
      return null;
    }
  }

  // Get all active exams
  static Future<List<Map<String, dynamic>>> getAllActiveExams() async {
    try {
      debugPrint('ACTIVE_EXAMS: Fetching all exams');
      final exams = await _client
          .from('exams')
          .select('*')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(exams);
    } catch (e) {
      debugPrint('ACTIVE_EXAMS: ERROR - $e');
      throw Exception('Failed to fetch active exams: $e');
    }
  }

  // Check if results are published for an exam
  static Future<bool> checkResultsPublished(String examCode) async {
    try {
      debugPrint('CHECK_PUBLISHED: Checking exam $examCode');
      final response = await _client
          .from('exams')
          .select('results_published')
          .eq('code', examCode)
          .single();
      
      final bool value = response['results_published'] ?? false;
      debugPrint('CHECK_PUBLISHED: Exam $examCode published: $value');
      return value;
    } catch (e) {
      debugPrint('CHECK_PUBLISHED: ERROR - $e');
      return false;
    }
  }

  // Get exam by code
  static Future<List<QuestionModel>> getExamByCode(String code) async {
    debugPrint('FETCH: Looking for exam with code: $code');
    try {
      final response = await _client
          .from('exams')
          .select()
          .eq('code', code)
          .single();
      
      debugPrint('FETCH: Response received: ${response.toString().substring(0, response.toString().length > 100 ? 100 : response.toString().length)}');
      debugPrint('FETCH: Title: ${response['title']}');
      
      final questionsJson = response['questions'] as List;
      debugPrint('FETCH: Questions count: ${questionsJson.length}');
      return questionsJson.map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q))).toList();
    } catch (e) {
      debugPrint('FETCH: ERROR - $e');
      throw Exception('Exam not found. Check the code and try again.');
    }
  }

  // Get exam details by code
  static Future<Map<String, dynamic>> getExamDetails(String code) async {
    try {
      debugPrint('EXAM_DETAILS: Looking for exam code: $code');
      final response = await _client
          .from('exams')
          .select('*')
          .eq('code', code)
          .single();
      
      print('EXAM_DETAILS: Fetched exam: ${response['title']}');
      return response;
    } catch (e) {
      debugPrint('EXAM_DETAILS: ERROR - $e');
      throw Exception('Exam not found. Check the code and try again.');
    }
  }

  // Validate if exam is within its time window
  static Map<String, dynamic> validateExamWindow(Map<String, dynamic> exam) {
    final mode = exam['timer_mode'] ?? 'none';
    
    if (mode == 'none') {
      return {'valid': true, 'message': ''};
    }
    
    if (mode == 'duration') {
      return {
        'valid': true, 
        'message': '', 
        'reason': 'duration',
        'durationMinutes': exam['duration_minutes']
      };
    }
    
    if (mode == 'window') {
      final now = DateTime.now().toUtc();
      final start = DateTime.parse(exam['window_start']).toUtc();
      final end = DateTime.parse(exam['window_end']).toUtc();
      
      if (now.isBefore(start)) {
        return {
          'valid': false,
          'reason': 'not_started',
          'message': 'Exam has not started yet. Starts at ${start.toLocal()}',
          'startsAt': start,
        };
      }
      
      if (now.isAfter(end)) {
        return {
          'valid': false,
          'reason': 'expired',
          'message': 'Exam window has expired.',
          'endedAt': end,
        };
      }
      
      final remainingMinutes = end.difference(now).inMinutes;
      final result = {
        'valid': true,
        'message': '',
        'reason': 'window',
        'remainingMinutes': remainingMinutes,
        'windowEnd': end,
      };
      print('TIMER: Validation result: ${result['valid']} - ${result['message']}');
      return result;
    }
    
    return {'valid': true, 'message': ''};
  }

  // Save result to Supabase
  static Future<void> saveResult({
    required String examCode,
    required String enrollmentNumber,
    required int score,
    required int total,
    required List<int?> answers,
    required bool instantMode,
  }) async {
    debugPrint('RESULT: Saving for enrollment: $enrollmentNumber');
    debugPrint('RESULT: Exam code: $examCode');
    debugPrint('RESULT: Score: $score / $total');
    debugPrint('RESULT: Answers: $answers');
    debugPrint('RESULT: Mode: ${instantMode ? 'instant' : 'manual'}');
    try {
      await _client.from('results').insert({
        'exam_code': examCode,
        'enrollment_number': enrollmentNumber,
        'score': score,
        'total': total,
        'answers': answers,
      });
      
      debugPrint('RESULT: Saved successfully!');
    } catch (e) {
      debugPrint('RESULT: ERROR - $e');
      throw Exception('Failed to save result: $e');
    }
  }
}
