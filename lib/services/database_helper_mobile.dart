import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sleep_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

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

  Future<SleepRecord> create(SleepRecord record) async {
    final db = await instance.database;
    final Map<String, dynamic> row = record.toMap();
    row.remove('id');
    final id = await db.insert('sleep_records', row);
    return SleepRecord(
        id: id,
        sleepTime: record.sleepTime,
        wakeUpTime: record.wakeUpTime,
        score: record.score,
        performance: record.performance,
        hadDaytimeDrowsiness: record.hadDaytimeDrowsiness,
        hasAchievedGoal: record.hasAchievedGoal,
        memo: record.memo,
        didNotOversleep: record.didNotOversleep);
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
    return db.update(
      'sleep_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
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
