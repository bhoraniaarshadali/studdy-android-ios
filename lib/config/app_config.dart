import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get kieaApiKey => dotenv.env['KIEA_API_KEY'] ?? '';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  static bool get isConfigured =>
    kieaApiKey.isNotEmpty &&
    supabaseUrl.isNotEmpty &&
    supabaseAnonKey.isNotEmpty;
}
