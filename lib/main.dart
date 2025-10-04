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
  final prefs = await SharedPreferences.getInstance();
  final isMigrated = prefs.getBool('is_v2_migrated') ?? false;

  if (isMigrated) {
    return;
  }

  final db = await DatabaseHelper.instance.database;
  try {
    final oldTableInfo = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='sleep_records_v1'");
    if (oldTableInfo.isEmpty) {
      // Old table doesn't exist, no migration needed.
      await prefs.setBool('is_v2_migrated', true);
      return;
    }

    final List<Map<String, dynamic>> oldRecords = await db.query('sleep_records_v1');
    if (oldRecords.isEmpty) {
      await prefs.setBool('is_v2_migrated', true);
      return;
    }

    for (final oldMap in oldRecords) {
      final sleepTimeUTC = DateTime.parse(oldMap['sleepTime']);
      final wakeUpTimeUTC = DateTime.parse(oldMap['wakeUpTime']);

      // The old data was stored in UTC. Convert to local time for JST-based logic.
      final sleepTimeLocal = sleepTimeUTC.toLocal();
      final wakeUpTimeLocal = wakeUpTimeUTC.toLocal();

      final newRecord = SleepRecord(
        dataId: const Uuid().v4(),
        recordDate: getLogicalDate(wakeUpTimeLocal), // Determine recordDate from local wake-up time
        spec_version: 2,
        sleepTime: sleepTimeLocal,
        wakeUpTime: wakeUpTimeLocal,
        score: oldMap['score'],
        performance: oldMap['performance'],
        hadDaytimeDrowsiness: oldMap['hadDaytimeDrowsiness'] == 1,
        hasAchievedGoal: oldMap['hasAchievedGoal'] == 1,
        memo: oldMap['memo'],
        didNotOversleep: oldMap['didNotOversleep'] == 1,
      );

      await db.insert('sleep_records', newRecord.toMap());
    }

    // Optional: Drop the old table after successful migration
    // await db.execute('DROP TABLE sleep_records_v1');

    await prefs.setBool('is_v2_migrated', true);
    print('Successfully migrated ${oldRecords.length} records to v2 format.');

  } catch (e) {
    print('Data migration failed: $e');
    // Handle migration failure, maybe by clearing the new table to allow a retry next time.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('ja_JP');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Run data migration only on non-web platforms
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