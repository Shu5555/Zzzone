import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/sleep_record.dart';
import './api_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final ApiService _apiService = ApiService();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sleep.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE sleep_records ( 
  id $idType, 
  sleepTime TEXT NOT NULL,
  wakeUpTime TEXT NOT NULL,
  score $intType,
  performance $intType,
  hadDaytimeDrowsiness $intType,
  hasAchievedGoal $intType,
  memo $textType,
  didNotOversleep $intType
  )
''');
  }

  Future<void> _syncWithServer(SleepRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final isRankingEnabled = prefs.getBool('rankingParticipation') ?? false;
    final userId = prefs.getString('userId');

    if (isRankingEnabled && userId != null) {
      // DBから読み込んだUTC時刻を、一度ローカルのタイムゾーンに変換する
      final localSleepTime = record.sleepTime.toLocal();

      // 1日の区切りを午前4時とするルールを適用
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
    final db = await instance.database;
    final Map<String, dynamic> row = record.toMap();
    row.remove('id');
    final id = await db.insert('sleep_records', row);
    final newRecord = record.copyWith(id: id);

    await _syncWithServer(newRecord);

    return newRecord;
  }

  Future<SleepRecord?> readRecord(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'sleep_records',
      columns: ['id', 'sleepTime', 'wakeUpTime', 'score', 'performance', 'hadDaytimeDrowsiness', 'hasAchievedGoal', 'memo', 'didNotOversleep'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SleepRecord.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<SleepRecord>> readAllRecords() async {
    final db = await instance.database;
    final orderBy = 'sleepTime DESC';
    final result = await db.query('sleep_records', orderBy: orderBy);
    return result.map((json) => SleepRecord.fromMap(json)).toList();
  }

  Future<int> update(SleepRecord record) async {
    final db = await instance.database;
    final result = await db.update(
      'sleep_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );

    await _syncWithServer(record);

    return result;
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'sleep_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<SleepRecord?> getLatestRecord() async {
    final db = await instance.database;
    final result = await db.query(
      'sleep_records',
      orderBy: 'wakeUpTime DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return SleepRecord.fromMap(result.first);
    } else {
      return null;
    }
  }

  Future<List<SleepRecord>> getLatestRecords({int limit = 3}) async {
    final db = await instance.database;
    final result = await db.query(
      'sleep_records',
      orderBy: 'wakeUpTime DESC',
      limit: limit,
    );
    return result.map((json) => SleepRecord.fromMap(json)).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
