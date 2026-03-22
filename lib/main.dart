import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  debugPrint('App: Studdy started');
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://odbycjunebfncpkkbbew.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9kYnljanVuZWJmbmNwa2tiYmV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNjQyMDMsImV4cCI6MjA4OTc0MDIwM30.vbQQXjTR0qAxKsa0ca48ZaVKaPDs_qlmCowHYMkV6zc',
  );
  
  debugPrint('App: Supabase initialized');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studdy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
