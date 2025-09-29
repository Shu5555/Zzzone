import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/sleep_record.dart';
import './api_service.dart';

// Web用のインメモリデータベースヘルパー（shared_preferencesで永続化）
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  final ApiService _apiService = ApiService();
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

  Future<void> _syncWithServer(SleepRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final isRankingEnabled = prefs.getBool('rankingParticipation') ?? false;
    final userId = prefs.getString('userId');

    if (isRankingEnabled && userId != null) {
      final localSleepTime = record.sleepTime.toLocal();
      DateTime effectiveDate = localSleepTime;
      if (localSleepTime.hour < 4) {
        effectiveDate = effectiveDate.subtract(const Duration(days: 1));
      }
      final date = DateFormat('yyyy-MM-dd').format(effectiveDate);
      final duration = record.wakeUpTime.difference(record.sleepTime).inMinutes;

      await _apiService.submitRecord(userId, duration, date);
    }
  }

  Future<SleepRecord> create(SleepRecord record) async {
    await _ensureInitialized();
    final newRecord = record.copyWith(id: _idCounter++);
    _inMemoryDb.add(newRecord);
    await _persistData();
    await _syncWithServer(newRecord);
    return newRecord;
  }

  Future<SleepRecord?> readRecord(int id) async {
    await _ensureInitialized();
    try {
      return _inMemoryDb.firstWhere((record) => record.id == id);
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
    final index = _inMemoryDb.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _inMemoryDb[index] = record;
      await _persistData();
      await _syncWithServer(record);
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
      return 1;
    }
    return 0;
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

  Future close() async {
    // Webでは何もしない
  }
}