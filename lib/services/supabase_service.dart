import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_model.dart';
import 'teacher_auth_service.dart';

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
        'teacher_id': TeacherAuthService.currentTeacherId ?? 'unknown',
      });
      print('PUBLISH: Teacher ID: ${TeacherAuthService.currentTeacherId}');
      
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
      final teacherId = TeacherAuthService.currentTeacherId;
      print('TEACHER_EXAMS: Fetching for teacher: $teacherId');
      
      // 1. First fetch all exams for this teacher:
      final List<dynamic> exams = await _client
        .from('exams')
        .select('id, code, title, result_mode, results_published, created_at, timer_mode, duration_minutes, window_start, window_end')
        .eq('teacher_id', teacherId ?? '')
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
      final List<dynamic> resultsRaw = await _client
          .from('results')
          .select()
          .eq('exam_code', examCode)
          .order('score', ascending: false);
      
      final List<Map<String, dynamic>> enrichedResults = [];
      
      for (var res in resultsRaw) {
        final Map<String, dynamic> result = Map<String, dynamic>.from(res);
        try {
          // Fetch student name for this result
          final student = await _client
              .from('students')
              .select('name')
              .eq('enrollment_number', result['enrollment_number'])
              .single();
          
          result['student_name'] = student['name'] ?? result['enrollment_number'];
          print('RESULTS: Student name: ${result['student_name']}');
        } catch (e) {
          debugPrint('RESULTS: Could not fetch student name for ${result['enrollment_number']}');
          result['student_name'] = result['enrollment_number'];
        }
        enrichedResults.add(result);
      }
      
      debugPrint('EXAM_RESULTS: Fetched ${enrichedResults.length} enriched results for $examCode');
      return enrichedResults;
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
  static Future<Map<String, dynamic>> checkOrCreateStudent(String enrollmentNumber, {String? name}) async {
    try {
      // 1. Check if exists
      final response = await _client
          .from('students')
          .select('*')
          .eq('enrollment_number', enrollmentNumber)
          .single();
      
      print('STUDENT: Existing student found: $enrollmentNumber');
      return {'isNew': false, 'student': response};
    } catch (e) {
      // 2. Student not found, create new
      try {
        print('STUDENT: Student not found, creating new: $enrollmentNumber');
        final Map<String, dynamic> data = {'enrollment_number': enrollmentNumber};
        if (name != null) data['name'] = name;
        
        final newStudent = await _client
            .from('students')
            .insert(data)
            .select('*')
            .single();
        
        print('STUDENT: New student created: $enrollmentNumber, name: $name');
        return {'isNew': true, 'student': newStudent};
      } catch (insertError) {
        print('STUDENT: Create ERROR - $insertError');
        throw Exception('Failed to create student: $insertError');
      }
    }
  }

  // Update student name
  static Future<void> updateStudentName(String enrollmentNumber, String name) async {
    try {
      await _client
          .from('students')
          .update({'name': name})
          .eq('enrollment_number', enrollmentNumber);
      print('STUDENT: Name updated: $name');
    } catch (e) {
      print('STUDENT: Name update ERROR - $e');
    }
  }

  // Get student info by enrollment
  static Future<Map<String, dynamic>?> getStudentByEnrollment(String enrollmentNumber) async {
    try {
      final response = await _client
          .from('students')
          .select('*')
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

  // Delete exam and all associated results
  static Future<void> deleteExam(String examCode) async {
    try {
      debugPrint('DELETE: Starting deletion for exam: $examCode');
      
      // 1. First delete all results for this exam
      await _client
          .from('results')
          .delete()
          .eq('exam_code', examCode);
      debugPrint('DELETE: Deleted results for exam: $examCode');
      
      // 2. Then delete the exam itself
      await _client
          .from('exams')
          .delete()
          .eq('code', examCode);
      debugPrint('DELETE: Exam deleted successfully: $examCode');
    } catch (e) {
      debugPrint('DELETE: ERROR deleting exam $examCode - $e');
      throw Exception('Failed to delete exam: $e');
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
    int warnings = 0,
    int appSwitches = 0,
  }) async {
    debugPrint('RESULT: Saving for enrollment: $enrollmentNumber');
    debugPrint('RESULT: Exam code: $examCode');
    debugPrint('RESULT: Score: $score / $total');
    debugPrint('RESULT: Warnings: $warnings, Switches: $appSwitches');
    try {
      await _client.from('results').insert({
        'exam_code': examCode,
        'enrollment_number': enrollmentNumber,
        'score': score,
        'total': total,
        'answers': answers,
        'warnings': warnings,
        'app_switches': appSwitches,
      });
      
      debugPrint('RESULT: Saved successfully!');
    } catch (e) {
      debugPrint('RESULT: ERROR - $e');
      throw Exception('Failed to save result: $e');
    }
  }

  // Create or update exam session (tracking who joined)
  static Future<void> createExamSession(String examCode, String enrollmentNumber, String studentName) async {
    try {
      // Check if session already exists
      final existing = await _client
        .from('exam_sessions')
        .select('id')
        .eq('exam_code', examCode)
        .eq('enrollment_number', enrollmentNumber)
        .limit(1);
      
      if (existing.isNotEmpty) {
        // Update existing session to active
        await _client
          .from('exam_sessions')
          .update({
            'status': 'active', 
            'joined_at': DateTime.now().toUtc().toIso8601String(),
            'student_name': studentName
          })
          .eq('exam_code', examCode)
          .eq('enrollment_number', enrollmentNumber);
        print('SESSION: Updated existing session for $enrollmentNumber in $examCode');
        return;
      }
      
      await _client.from('exam_sessions').insert({
        'exam_code': examCode,
        'enrollment_number': enrollmentNumber,
        'student_name': studentName,
        'status': 'active',
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });
      print('SESSION: Created session for $enrollmentNumber in exam $examCode');
    } catch(e) {
      print('SESSION: Error creating session - $e');
      // Don't throw - session tracking failure should not block exam
    }
  }

  // Mark session as submitted
  static Future<void> updateExamSessionSubmitted(String examCode, String enrollmentNumber) async {
    try {
      await _client
        .from('exam_sessions')
        .update({
          'status': 'submitted',
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('exam_code', examCode)
        .eq('enrollment_number', enrollmentNumber);
      print('SESSION: Marked submitted for $enrollmentNumber in $examCode');
    } catch(e) {
      print('SESSION: Error updating session - $e');
    }
  }

  // Get all session info for an exam
  static Future<List<Map<String, dynamic>>> getExamSessions(String examCode) async {
    try {
      final response = await _client
        .from('exam_sessions')
        .select('*')
        .eq('exam_code', examCode)
        .order('joined_at', ascending: false);
      print('SESSION: Fetched ${response.length} sessions for $examCode');
      return List<Map<String, dynamic>>.from(response);
    } catch(e) {
      print('SESSION: Error fetching sessions - $e');
      return [];
    }
  }

  // Update session warning (increment or type)
  static Future<void> updateExamSessionWarning(String examCode, String enrollmentNumber, {required String warningType}) async {
    try {
      final session = await _client
        .from('exam_sessions')
        .select('warnings, warnings_log')
        .eq('exam_code', examCode)
        .eq('enrollment_number', enrollmentNumber)
        .maybeSingle();
      
      int currentWarnings = 0;
      List<dynamic> logs = [];
      
      if (session != null) {
        currentWarnings = (session['warnings'] ?? 0) as int;
        logs = List.from(session['warnings_log'] ?? []);
      }
      
      logs.add({
        'type': warningType,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      
      await _client
        .from('exam_sessions')
        .update({
          'warnings': currentWarnings + 1,
          'warnings_log': logs,
          'last_warning_at': DateTime.now().toUtc().toIso8601String(),
          'last_warning_type': warningType,
        })
        .eq('exam_code', examCode)
        .eq('enrollment_number', enrollmentNumber);
        
      print('SESSION_WARNING: $warningType for $enrollmentNumber');
    } catch(e) {
      print('SESSION: Error recording warning - $e');
    }
  }
}
