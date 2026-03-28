import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<Map<String, dynamic>?> getSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enrollment = prefs.getString('student_enrollment');
      if (enrollment != null) {
        return {
          'isLoggedIn': true,
          'isTeacher': false,
          'enrollmentNumber': enrollment,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('student_enrollment');
      print('AUTH_SERVICE: Student session cleared');
    } catch (e) {
      print('AUTH_SERVICE: Logout ERROR - $e');
    }
  }
}
