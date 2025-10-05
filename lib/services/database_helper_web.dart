import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/sleep_record.dart';
import '../utils/date_helper.dart';

// Web用のインメモリデータベースヘルパー（shared_preferencesで永続化）
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  final List<SleepRecord> _inMemoryDb = [];
  bool _isInitialized = false;
  static const _kSleepRecordsKeyV2 = 'sleep_records_json_v2';
  static const _kSleepRecordsKeyV1 = 'sleep_records_json';

  // Dummy getter for mobile compatibility (e.g., for migration script)
  Future<dynamic> get database async {
    await _ensureInitialized();
    return null; // Return null or a mock object, as it's not used on web
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    
    // 1. Try to load v2 data first
    String? jsonString = prefs.getString(_kSleepRecordsKeyV2);

    if (jsonString != null) {
      // V2 data exists, load it
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _inMemoryDb.clear();
        _inMemoryDb.addAll(jsonList.map((json) => SleepRecord.fromMap(json as Map<String, dynamic>)));
      } catch (e) {
        await prefs.remove(_kSleepRecordsKeyV2);
      }
    } else {
      // 2. V2 data doesn't exist, try to load and migrate V1 data
      jsonString = prefs.getString(_kSleepRecordsKeyV1);
      if (jsonString != null) {
        try {
          final List<dynamic> oldJsonList = jsonDecode(jsonString);
          final List<SleepRecord> migratedRecords = [];

          for (final oldMap in oldJsonList) {
            // V1 data might not have all fields, provide defaults
            final sleepTimeUTC = DateTime.parse(oldMap['sleepTime']);
            final wakeUpTimeUTC = DateTime.parse(oldMap['wakeUpTime']);
            final sleepTimeLocal = sleepTimeUTC.toLocal();
            final wakeUpTimeLocal = wakeUpTimeUTC.toLocal();

            migratedRecords.add(SleepRecord(
              dataId: const Uuid().v4(),
              recordDate: getLogicalDate(wakeUpTimeLocal),
              spec_version: 2,
              sleepTime: sleepTimeLocal,
              wakeUpTime: wakeUpTimeLocal,
              score: oldMap['score'] ?? 5,
              performance: oldMap['performance'] ?? 2,
              hadDaytimeDrowsiness: oldMap['hadDaytimeDrowsiness'] == 1,
              hasAchievedGoal: oldMap['hasAchievedGoal'] == 1,
              memo: oldMap['memo'],
              didNotOversleep: oldMap['didNotOversleep'] == 1,
            ));
          }
          _inMemoryDb.clear();
          _inMemoryDb.addAll(migratedRecords);
          
          // 3. Persist migrated data to new key and remove old key
          await _persistData();
          await prefs.remove(_kSleepRecordsKeyV1);

        } catch (e) {
          await prefs.remove(_kSleepRecordsKeyV1);
        }
      }
    }

    _isInitialized = true;
  }

  Future<void> _persistData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _inMemoryDb.map((r) => r.toMap()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_kSleepRecordsKeyV2, jsonString);
  }

  Future<SleepRecord> create(SleepRecord record) async {
    await _ensureInitialized();
    _inMemoryDb.add(record);
    await _persistData();
    return record;
  }

  Future<SleepRecord?> readRecord(String dataId) async {
    await _ensureInitialized();
    try {
      return _inMemoryDb.firstWhere((record) => record.dataId == dataId);
    } catch (e) {
      return null;
    }
  }

  Future<List<SleepRecord>> readAllRecords() async {
    await _ensureInitialized();
    final sortedList = List<SleepRecord>.from(_inMemoryDb);
    sortedList.sort((a, b) {
      int dateCompare = b.recordDate.compareTo(a.recordDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return b.wakeUpTime.compareTo(a.wakeUpTime);
    });
    return sortedList;
  }

  Future<int> update(SleepRecord record) async {
    await _ensureInitialized();
    final index = _inMemoryDb.indexWhere((r) => r.dataId == record.dataId);
    if (index != -1) {
      _inMemoryDb[index] = record;
      await _persistData();
      return 1;
    }
    return 0;
  }

  Future<int> delete(String dataId) async {
    await _ensureInitialized();
    final initialLength = _inMemoryDb.length;
    _inMemoryDb.removeWhere((r) => r.dataId == dataId);
    if (initialLength > _inMemoryDb.length) {
      await _persistData();
      return 1;
    }
    return 0;
  }

  Future<int> deleteAllRecords() async {
    await _ensureInitialized();
    final recordsDeleted = _inMemoryDb.length;
    _inMemoryDb.clear();
    await _persistData();
    return recordsDeleted;
  }

  Future<SleepRecord?> getLatestRecord() async {
    await _ensureInitialized();
    if (_inMemoryDb.isEmpty) return null;
    final sortedList = List<SleepRecord>.from(_inMemoryDb);
    sortedList.sort((a, b) => b.wakeUpTime.compareTo(a.wakeUpTime));
    return sortedList.first;
  }

  Future<List<SleepRecord>> getLatestRecords({int limit = 3}) async {
    await _ensureInitialized();
    if (_inMemoryDb.isEmpty) return [];
    final sortedList = List<SleepRecord>.from(_inMemoryDb);
    sortedList.sort((a, b) => b.wakeUpTime.compareTo(a.wakeUpTime));
    return sortedList.take(limit).toList();
  }

  Future<SleepRecord?> getRecordForDate(DateTime date) async {
    await _ensureInitialized();
    final targetLogicalDate = getLogicalDate(date);

    for (var record in _inMemoryDb) {
      if (record.recordDate == targetLogicalDate) {
        return record;
      }
    }
    return null;
  }

  Future close() async {
    // No-op for web
  }
}
