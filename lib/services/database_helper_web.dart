import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';
import '../utils/date_helper.dart';

// Web用のインメモリデータベースヘルパー（shared_preferencesで永続化）
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  final List<SleepRecord> _inMemoryDb = [];
  bool _isInitialized = false;
  static const _kSleepRecordsKey = 'sleep_records_json_v2'; // Use a new key for v2

  // Dummy getter for mobile compatibility (e.g., for migration script)
  Future<dynamic> get database async {
    await _ensureInitialized();
    return null; // Return null or a mock object, as it's not used on web
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kSleepRecordsKey);

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _inMemoryDb.clear();
        _inMemoryDb.addAll(jsonList.map((json) => SleepRecord.fromMap(json as Map<String, dynamic>)));
      } catch (e) {
        // Handle potential parsing errors with old/corrupt data
        await prefs.remove(_kSleepRecordsKey);
      }
    }
    _isInitialized = true;
  }

  Future<void> _persistData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _inMemoryDb.map((r) => r.toMap()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_kSleepRecordsKey, jsonString);
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
    sortedList.sort((a, b) => b.sleepTime.compareTo(a.sleepTime));
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