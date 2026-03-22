import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard_screen.dart';

void main() async {
  debugPrint('App: Studdy started');
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://odbycjunebfncpkkbbew.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9kYnljanVuZWJmbmNwa2tiYmV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNjQyMDMsImV4cCI6MjA4OTc0MDIwM30.vbQQXjTR0qAxKsa0ca48ZaVKaPDs_qlmCowHYMkV6zc',
  );
  
  debugPrint('App: Supabase initialized');
  
  final prefs = await SharedPreferences.getInstance();
  final enrollment = prefs.getString('student_enrollment');
  if (enrollment != null) {
    debugPrint('App: Persistent session found for $enrollment');
  }
  
  runApp(MyApp(initialEnrollment: enrollment));
}

class MyApp extends StatelessWidget {
  final String? initialEnrollment;
  const MyApp({super.key, this.initialEnrollment});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studdy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: initialEnrollment != null 
          ? StudentDashboardScreen(enrollmentNumber: initialEnrollment!)
          : const LoginScreen(),
    );
  }
}
