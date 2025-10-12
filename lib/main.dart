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
import 'utils/date_helper.dart';

Future<void> _runDataMigration() async {
  // ... (omitted, no change)
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    await dotenv.load(fileName: ".env");
  }
  await initializeDateFormatting('ja_JP');

  await Supabase.initialize(
    url: kDebugMode ? dotenv.env['SUPABASE_URL']! : const String.fromEnvironment('SUPABASE_URL'),
    anonKey: kDebugMode ? dotenv.env['SUPABASE_ANON_KEY']! : const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  if (!kIsWeb) {
    await _runDataMigration();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const HomeScreen(),
    );
  }
}