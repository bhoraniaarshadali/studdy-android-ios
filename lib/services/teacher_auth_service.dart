import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherAuthService {
  static final _client = Supabase.instance.client;

  // Get current logged in teacher
  static User? get currentTeacher => _client.auth.currentUser;
  static String? get currentTeacherId => _client.auth.currentUser?.id;
  static bool get isLoggedIn => _client.auth.currentUser != null;

  // Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      print('TEACHER_AUTH: Signing up: $email');
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': 'teacher'},
      );
      print('TEACHER_AUTH: Sign up successful: ${response.user?.id}');
      return response;
    } catch (e) {
      print('TEACHER_AUTH: Sign up ERROR - $e');
      rethrow;
    }
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('TEACHER_AUTH: Signing in: $email');
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print('TEACHER_AUTH: Sign in successful: ${response.user?.id}');
      return response;
    } catch (e) {
      print('TEACHER_AUTH: Sign in ERROR - $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      print('TEACHER_AUTH: Signing out');
      await _client.auth.signOut();
      print('TEACHER_AUTH: Signed out successfully');
    } catch (e) {
      print('TEACHER_AUTH: Sign out ERROR - $e');
      rethrow;
    }
  }

  // Get teacher name from metadata
  static String get teacherName {
    final metadata = _client.auth.currentUser?.userMetadata;
    return metadata?['name'] ?? 'Teacher';
  }

  // Get teacher email
  static String get teacherEmail {
    return _client.auth.currentUser?.email ?? '';
  }

  // Check if session is valid
  static Future<bool> hasValidSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return false;
      print('TEACHER_AUTH: Valid session found for: ${currentTeacher?.email}');
      return true;
    } catch (e) {
      print('TEACHER_AUTH: Session check ERROR - $e');
      return false;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      print('TEACHER_AUTH: Password reset email sent to: $email');
    } catch (e) {
      print('TEACHER_AUTH: Reset password ERROR - $e');
      rethrow;
    }
  }
}
