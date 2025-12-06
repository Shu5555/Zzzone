import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models/sleep_record.dart';
import 'screens/home_screen.dart';
import 'services/database_helper.dart';
import 'services/dropbox_service.dart';
import 'package:sleep_management_app/services/supabase_ranking_service.dart';
import 'utils/date_helper.dart';

Future<void> _runDataMigration() async {
  // ... (omitted, no change)
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file in debug mode
  if (kDebugMode) {
    await dotenv.load(fileName: 'assets/.env');
  }

  // Handle Dropbox web auth callback before the app starts
  if (kIsWeb) {
    final uri = Uri.base;
    if (uri.queryParameters.containsKey('code')) {
      final dropboxService = DropboxService();
      try {
        await dropboxService.handleWebAuthCallback(uri);
        // Optionally, you could navigate away or clear the URL here
      } catch (e) {
        if (kDebugMode) {
          print('Error handling Dropbox web auth callback: $e');
        }
      }
    }
  }

  await initializeDateFormatting('ja_JP');

  // Initialize Supabase with environment variables
  final supabaseUrl = kDebugMode
      ? (dotenv.env['SUPABASE_URL'] ?? '')
      : const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = kDebugMode
      ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '')
      : const String.fromEnvironment('SUPABASE_ANON_KEY');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  if (!kIsWeb) {
    await _runDataMigration();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final SupabaseRankingService? supabaseService;
  const MyApp({super.key, this.supabaseService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zzzone',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'MPLUSRounded1c',
        primaryColor: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
      ),
      home: HomeScreen(supabaseService: supabaseService),
    );
  }
}