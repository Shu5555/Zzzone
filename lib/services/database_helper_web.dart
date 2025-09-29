import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';

// Web用のインメモリデータベースヘルパー（shared_preferencesで永続化）
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  final List<SleepRecord> _inMemoryDb = [];
  int _idCounter = 0;
  bool _isInitialized = false;
  static const _kSleepRecordsKey = 'sleep_records_json';

  // データの読み込み（初回のみ実行）
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kSleepRecordsKey);

    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _inMemoryDb.clear();
      _inMemoryDb.addAll(jsonList.map((json) => SleepRecord.fromMap(json as Map<String, dynamic>)));

      if (_inMemoryDb.isNotEmpty) {
        // IDの最大値から次のIDを払い出すように設定
        _idCounter = _inMemoryDb.map((r) => r.id ?? 0).reduce((max, current) => max > current ? max : current) + 1;
      }
    }
    _isInitialized = true;
  }

  // データの保存
  Future<void> _persistData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _inMemoryDb.map((r) => r.toMap()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_kSleepRecordsKey, jsonString);
  }

  Future<SleepRecord> create(SleepRecord record) async {
    await _ensureInitialized();
    final newRecord = SleepRecord(
      id: _idCounter++,
      sleepTime: record.sleepTime,
      wakeUpTime: record.wakeUpTime,
      score: record.score,
      performance: record.performance,
      hadDaytimeDrowsiness: record.hadDaytimeDrowsiness,
      hasAchievedGoal: record.hasAchievedGoal,
      memo: record.memo,
      didNotOversleep: record.didNotOversleep,
    );
    _inMemoryDb.add(newRecord);
    await _persistData();
    return newRecord;
  }

  Future<SleepRecord?> readRecord(int id) async {
    await _ensureInitialized();
    return _inMemoryDb.firstWhere((record) => record.id == id, orElse: () => throw Exception('Record not found'));
  }

  Future<List<SleepRecord>> readAllRecords() async {
    await _ensureInitialized();
    // データを返す前にソートする
    _inMemoryDb.sort((a, b) => b.sleepTime.compareTo(a.sleepTime));
    return List.from(_inMemoryDb);
  }

  Future<int> update(SleepRecord record) async {
    await _ensureInitialized();
    final index = _inMemoryDb.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _inMemoryDb[index] = record;
      await _persistData();
      return 1;
    }
    return 0;
  }

  Future<int> delete(int id) async {
    await _ensureInitialized();
    final initialLength = _inMemoryDb.length;
    _inMemoryDb.removeWhere((r) => r.id == id);
    if (initialLength > _inMemoryDb.length) {
      await _persistData();
      return 1; // 1行削除された
    }
    return 0; // 何も削除されなかった
  }

  Future<SleepRecord?> getLatestRecord() async {
    await _ensureInitialized();
    if (_inMemoryDb.isEmpty) return null;
    _inMemoryDb.sort((a, b) => b.wakeUpTime.compareTo(a.wakeUpTime));
    return _inMemoryDb.first;
  }

  Future<List<SleepRecord>> getLatestRecords({int limit = 3}) async {
    await _ensureInitialized();
    if (_inMemoryDb.isEmpty) return [];
    _inMemoryDb.sort((a, b) => b.wakeUpTime.compareTo(a.wakeUpTime));
    return _inMemoryDb.take(limit).toList();
  }

  Future close() async {
    // Webでは何もしない
  }
}
