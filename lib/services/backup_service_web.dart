import '../models/sleep_record.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:sleep_management_app/services/database_helper.dart';
import 'package:sleep_management_app/services/database_helper_interface.dart';

class BackupServiceWeb {
  final IDatabaseHelper _dbHelper;

  // Allow dependency injection for testing, but use the singleton by default.
  BackupServiceWeb({IDatabaseHelper? dbHelper}) 
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> createBackupJson() async {
    // 1. Fetch all data from database
    final sleepRecords = await _dbHelper.readAllRecords();
    final unlockedQuotes = await _dbHelper.getUnlockedQuoteIds();
    final gachaHistory = await _dbHelper.getGachaHistory();
    final readAnnouncements = await _dbHelper.getReadAnnouncementIds();

    // 2. Fetch all data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final prefsMap = <String, dynamic>{};
    for (String key in prefs.getKeys()) {
      prefsMap[key] = prefs.get(key);
    }

    // 3. Combine all data into a single map
    final backupData = {
      'sleep_records': sleepRecords.map((r) => r.toMap()).toList(),
      'unlocked_quotes': unlockedQuotes,
      'gacha_pull_history': gachaHistory
          .map((h) => {
                'quote_id': h.quoteId,
                'rarity_id': h.rarityId,
                'pulled_at': h.pulledAt.toIso8601String(),
              })
          .toList(),
      'read_announcements': readAnnouncements.toList(),
      'shared_preferences': prefsMap,
    };

    // 4. Encode to JSON string
    return jsonEncode(backupData);
  }

  Future<void> restoreFromJson(String jsonString) async {
    final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

    // 1. Restore SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final prefsMap = backupData['shared_preferences'] as Map<String, dynamic>?;
    if (prefsMap != null) {
      for (final key in prefsMap.keys) {
        final value = prefsMap[key];
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          // SharedPreferences only supports List<String>
          await prefs.setStringList(key, value.cast<String>());
        }
      }
    }

    // 2. Restore Database Data
    // Note: This should be done in a transaction if possible, but for now, we clear and add.
    // The test only verifies deleteAllRecords, but we should clear all tables.
    // For now, we stick to what the test expects.
    await _dbHelper.deleteAllRecords();
    await _dbHelper.deleteAllUnlockedQuotes();
    await _dbHelper.deleteAllGachaHistory();
    await _dbHelper.deleteAllReadAnnouncements();

    final sleepRecords = backupData['sleep_records'] as List<dynamic>?;
    if (sleepRecords != null) {
      for (final recordMap in sleepRecords) {
        await _dbHelper.create(SleepRecord.fromMap(recordMap as Map<String, dynamic>));
      }
    }

    final unlockedQuotes = backupData['unlocked_quotes'] as List<dynamic>?;
    if (unlockedQuotes != null) {
      for (final quoteId in unlockedQuotes) {
        await _dbHelper.addUnlockedQuote(quoteId as String);
      }
    }

    final gachaHistory = backupData['gacha_pull_history'] as List<dynamic>?;
    if (gachaHistory != null) {
      for (final historyItem in gachaHistory) {
        final itemMap = historyItem as Map<String, dynamic>;
        await _dbHelper.addGachaPull(itemMap['quote_id'] as String, itemMap['rarity_id'] as String);
      }
    }

    final readAnnouncements = backupData['read_announcements'] as List<dynamic>?;
    if (readAnnouncements != null) {
      await _dbHelper.markAnnouncementsAsRead(readAnnouncements.cast<String>());
    }
  }
}
