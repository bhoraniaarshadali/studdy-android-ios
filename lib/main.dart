import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'screens/teacher/dashboard_screen.dart';
import 'services/teacher_auth_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: '.env');
  print('APP: Config loaded - configured: ${AppConfig.isConfigured}');
  
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
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
