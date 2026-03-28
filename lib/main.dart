import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'screens/teacher/dashboard_screen.dart';
import 'services/teacher_auth_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://odbycjunebfncpkkbbew.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9kYnljanVuZWJmbmNwa2tiYmV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNjQyMDMsImV4cCI6MjA4OTc0MDIwM30.vbQQXjTR0qAxKsa0ca48ZaVKaPDs_qlmCowHYMkV6zc',
  );
  
  FlutterError.onError = (FlutterErrorDetails details) {
    print('FLUTTER_ERROR: ${details.exception}');
    print('FLUTTER_ERROR: ${details.stack}');
  };
  
  Widget homeScreen;
  
  // Check teacher session first (Supabase Auth)
  final hasTeacherSession = await TeacherAuthService.hasValidSession();
  
  if (hasTeacherSession) {
    homeScreen = const TeacherDashboardScreen();
    print('APP: Teacher auto-login: ${TeacherAuthService.teacherEmail}');
  } else {
    // Check student session (SharedPreferences)
    final savedLogin = await AuthService.getSavedLogin();
    
    if (savedLogin != null && savedLogin['isLoggedIn'] == true && savedLogin['isTeacher'] == false) {
      homeScreen = StudentDashboardScreen(
        enrollmentNumber: savedLogin['enrollmentNumber'],
        isNew: false,
        pendingExamCode: null,
      );
      print('APP: Student auto-login: ${savedLogin['enrollmentNumber']}');
    } else {
      homeScreen = const LoginScreen();
      print('APP: No saved session, showing login screen');
    }
  }
  
  runApp(MyApp(homeScreen: homeScreen));
}

class MyApp extends StatelessWidget {
  final Widget homeScreen;
  const MyApp({super.key, required this.homeScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studdy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: homeScreen,
    );
  }
}
