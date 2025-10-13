import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/sleep_record.dart';
import '../utils/date_helper.dart';

// Helper class for Gacha History
class GachaPullRecord {
  final String quoteId;
  final String rarityId;
  final DateTime pulledAt;
  GachaPullRecord({required this.quoteId, required this.rarityId, required this.pulledAt});
}

// Web用のインメモリデータベースヘルパー（shared_preferencesで永続化）
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  // In-memory stores
  final List<SleepRecord> _inMemoryDb = [];
  final List<String> _unlockedQuotes = [];
  final List<Map<String, String>> _gachaHistory = [];
  final Set<String> _readAnnouncements = {}; // New
  bool _isInitialized = false;

  // SharedPreferences keys
  static const _kSleepRecordsKeyV2 = 'sleep_records_json_v2';
  static const _kSleepRecordsKeyV1 = 'sleep_records_json';
  static const _kUnlockedQuotesKey = 'unlocked_quotes_json';
  static const _kGachaHistoryKey = 'gacha_history_json';
  static const _kReadAnnouncementsKey = 'read_announcements_json'; // New

  Future<dynamic> get database async {
    await _ensureInitialized();
    return null;
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    
    _loadSleepRecords(prefs);
    _loadUnlockedQuotes(prefs);
    _loadGachaHistory(prefs);
    _loadReadAnnouncements(prefs); // New

    _isInitialized = true;
  }

  void _loadSleepRecords(SharedPreferences prefs) {
    String? jsonString = prefs.getString(_kSleepRecordsKeyV2);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _inMemoryDb.clear();
        _inMemoryDb.addAll(jsonList.map((json) => SleepRecord.fromMap(json as Map<String, dynamic>)));
      } catch (e) { /* Handle error */ }
    } else {
      jsonString = prefs.getString(_kSleepRecordsKeyV1);
      if (jsonString != null) {
        try {
          final List<dynamic> oldJsonList = jsonDecode(jsonString);
          final List<SleepRecord> migratedRecords = [];
          for (final oldMap in oldJsonList) {
            final sleepTimeUTC = DateTime.parse(oldMap['sleepTime']);
            final wakeUpTimeUTC = DateTime.parse(oldMap['wakeUpTime']);
            migratedRecords.add(SleepRecord(
              dataId: const Uuid().v4(),
              recordDate: getLogicalDate(wakeUpTimeUTC.toLocal()),
              spec_version: 2,
              sleepTime: sleepTimeUTC.toLocal(),
              wakeUpTime: wakeUpTimeUTC.toLocal(),
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
          _persistSleepRecords();
          prefs.remove(_kSleepRecordsKeyV1);
        } catch (e) { /* Handle error */ }
      }
    }
  }

  void _loadUnlockedQuotes(SharedPreferences prefs) {
    final jsonString = prefs.getString(_kUnlockedQuotesKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _unlockedQuotes.clear();
        _unlockedQuotes.addAll(jsonList.cast<String>());
      } catch (e) { /* Handle error */ }
    }
  }

  void _loadGachaHistory(SharedPreferences prefs) {
    final jsonString = prefs.getString(_kGachaHistoryKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _gachaHistory.clear();
        _gachaHistory.addAll(jsonList.map((item) => Map<String, String>.from(item)));
      } catch (e) { /* Handle error */ }
    }
  }

  void _loadReadAnnouncements(SharedPreferences prefs) {
    final jsonString = prefs.getString(_kReadAnnouncementsKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _readAnnouncements.clear();
        _readAnnouncements.addAll(jsonList.cast<String>());
      } catch (e) { /* Handle error */ }
    }
  }

  Future<void> _persistSleepRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _inMemoryDb.map((r) => r.toMap()).toList();
    await prefs.setString(_kSleepRecordsKeyV2, jsonEncode(jsonList));
  }

  Future<void> _persistUnlockedQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnlockedQuotesKey, jsonEncode(_unlockedQuotes));
  }

  Future<void> _persistGachaHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGachaHistoryKey, jsonEncode(_gachaHistory));
  }

  Future<void> _persistReadAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReadAnnouncementsKey, jsonEncode(_readAnnouncements.toList()));
  }

  // --- SleepRecord Methods ---

  Future<SleepRecord> create(SleepRecord record) async {
    await _ensureInitialized();
    _inMemoryDb.add(record);
    await _persistSleepRecords();
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
      if (dateCompare != 0) return dateCompare;
      return b.wakeUpTime.compareTo(a.wakeUpTime);
    });
    return sortedList;
  }

  Future<int> update(SleepRecord record) async {
    await _ensureInitialized();
    final index = _inMemoryDb.indexWhere((r) => r.dataId == record.dataId);
    if (index != -1) {
      _inMemoryDb[index] = record;
      await _persistSleepRecords();
      return 1;
    }
    return 0;
  }

  Future<int> delete(String dataId) async {
    await _ensureInitialized();
    final initialLength = _inMemoryDb.length;
    _inMemoryDb.removeWhere((r) => r.dataId == dataId);
    if (initialLength > _inMemoryDb.length) {
      await _persistSleepRecords();
      return 1;
    }
    return 0;
  }

  Future<int> deleteAllRecords() async {
    await _ensureInitialized();
    final count = _inMemoryDb.length;
    _inMemoryDb.clear();
    await _persistSleepRecords();
    return count;
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

  // --- Gacha Quote Methods ---

  Future<bool> addUnlockedQuote(String quoteId) async {
    await _ensureInitialized();
    if (!_unlockedQuotes.contains(quoteId)) {
      _unlockedQuotes.add(quoteId);
      await _persistUnlockedQuotes();
      return true; // Newly added
    }
    return false; // Already existed
  }

  Future<List<String>> getUnlockedQuoteIds() async {
    await _ensureInitialized();
    return List<String>.from(_unlockedQuotes.reversed);
  }

  Future<void> addGachaPull(String quoteId, String rarityId) async {
    await _ensureInitialized();
    _gachaHistory.add({
      'quote_id': quoteId,
      'rarity_id': rarityId,
      'pulled_at': DateTime.now().toIso8601String(),
    });
    await _persistGachaHistory();
  }

  Future<List<GachaPullRecord>> getGachaHistory() async {
    await _ensureInitialized();
    final sortedHistory = List<Map<String, String>>.from(_gachaHistory);
    sortedHistory.sort((a, b) => b['pulled_at']!.compareTo(a['pulled_at']!));
    return sortedHistory.map((row) => GachaPullRecord(
      quoteId: row['quote_id']!,
      rarityId: row['rarity_id']!,
      pulledAt: DateTime.parse(row['pulled_at']!),
    )).toList();
  }

  // --- Announcement Methods ---

  Future<void> markAnnouncementsAsRead(List<String> announcementIds) async {
    await _ensureInitialized();
    _readAnnouncements.addAll(announcementIds);
    await _persistReadAnnouncements();
  }

  Future<Set<String>> getReadAnnouncementIds() async {
    await _ensureInitialized();
    return _readAnnouncements;
  }

  Future close() async {
    // No-op for web
  }
}
