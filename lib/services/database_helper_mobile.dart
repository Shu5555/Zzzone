import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sleep_record.dart';
import '../utils/date_helper.dart';

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

    // DBバージョンを2に更新
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE sleep_records ( 
  dataId TEXT PRIMARY KEY, 
  recordDate $textType,
  spec_version $intType,
  sleepTime $textType,
  wakeUpTime $textType,
  score $intType,
  performance $intType,
  hadDaytimeDrowsiness $intType,
  hasAchievedGoal $intType,
  memo TEXT,
  didNotOversleep $intType
  )
''');
  }

  // スキーママイグレーションのロジック
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Phase 4のデータ移行で扱うため、ここではスキーマ変更のみ
      // 既存のテーブルをリネームして退避
      await db.execute('ALTER TABLE sleep_records RENAME TO sleep_records_v1');
      // 新しいテーブルを作成
      await _createDB(db, newVersion);
    }
  }

  Future<SleepRecord> create(SleepRecord record) async {
    final db = await instance.database;
    await db.insert('sleep_records', record.toMap());
    return record;
  }

  Future<SleepRecord?> readRecord(String dataId) async {
    final db = await instance.database;
    final maps = await db.query(
      'sleep_records',
      where: 'dataId = ?',
      whereArgs: [dataId],
    );

    if (maps.isNotEmpty) {
      return SleepRecord.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<SleepRecord>> readAllRecords() async {
    final db = await instance.database;
    final orderBy = 'recordDate DESC, wakeUpTime DESC';
    final result = await db.query('sleep_records', orderBy: orderBy);
    return result.map((json) => SleepRecord.fromMap(json)).toList();
  }

  Future<int> update(SleepRecord record) async {
    final db = await instance.database;
    final result = await db.update(
      'sleep_records',
      record.toMap(),
      where: 'dataId = ?',
      whereArgs: [record.dataId],
    );
    return result;
  }

  Future<int> delete(String dataId) async {
    final db = await instance.database;
    return await db.delete(
      'sleep_records',
      where: 'dataId = ?',
      whereArgs: [dataId],
    );
  }

  Future<int> deleteAllRecords() async {
    final db = await instance.database;
    return await db.delete('sleep_records');
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

  Future<SleepRecord?> getRecordForDate(DateTime date) async {
    final db = await instance.database;
    final targetLogicalDate = getLogicalDate(date);
    final result = await db.query(
      'sleep_records',
      where: 'recordDate = ?',
      whereArgs: [targetLogicalDate.toIso8601String().substring(0, 10)], // yyyy-MM-dd形式で比較
      limit: 1,
    );

    if (result.isNotEmpty) {
      return SleepRecord.fromMap(result.first);
    } else {
      return null;
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}