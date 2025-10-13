import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/sleep_record.dart';
import '../utils/date_helper.dart';

// Helper class for Gacha History
class GachaPullRecord {
  final String quoteId;
  final String rarityId;
  final DateTime pulledAt;
  GachaPullRecord({required this.quoteId, required this.rarityId, required this.pulledAt});
}

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

    return await openDatabase(path, version: 5, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    // sleep_records table
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

    // unlocked_quotes table
    await db.execute('''
CREATE TABLE unlocked_quotes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id TEXT NOT NULL UNIQUE,
  unlocked_at TEXT NOT NULL
)
''');

    // gacha_pull_history table
    await db.execute('''
CREATE TABLE gacha_pull_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id TEXT NOT NULL,
  rarity_id TEXT NOT NULL,
  pulled_at TEXT NOT NULL
)
''');

    // read_announcements table
    await _createReadAnnouncementsTable(db);
  }

  Future<void> _createReadAnnouncementsTable(Database db) async {
    await db.execute('''
CREATE TABLE read_announcements (
  id TEXT PRIMARY KEY
)
''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sleep_records RENAME TO sleep_records_v1');
      await _createDB(db, newVersion);
      return;
    }
    if (oldVersion < 3) {
      await db.execute('''
CREATE TABLE unlocked_quotes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id TEXT NOT NULL UNIQUE,
  unlocked_at TEXT NOT NULL
)
''');
    }
    if (oldVersion < 4) {
      await db.execute('''
CREATE TABLE gacha_pull_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id TEXT NOT NULL,
  rarity_id TEXT NOT NULL,
  pulled_at TEXT NOT NULL
)
''');
    }
    if (oldVersion < 5) {
      await _createReadAnnouncementsTable(db);
    }
  }

  // --- SleepRecord Methods ---

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
      whereArgs: [targetLogicalDate.toIso8601String().substring(0, 10)],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return SleepRecord.fromMap(result.first);
    } else {
      return null;
    }
  }

  // --- Gacha Quote Methods ---

  Future<bool> addUnlockedQuote(String quoteId) async {
    final db = await instance.database;

    final existingQuotes = await db.query(
      'unlocked_quotes',
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      limit: 1,
    );

    if (existingQuotes.isNotEmpty) {
      return false;
    } else {
      await db.insert(
        'unlocked_quotes',
        {
          'quote_id': quoteId,
          'unlocked_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    }
  }

  Future<List<String>> getUnlockedQuoteIds() async {
    final db = await instance.database;
    final result = await db.query('unlocked_quotes', columns: ['quote_id'], orderBy: 'unlocked_at DESC');
    return result.map((row) => row['quote_id'] as String).toList();
  }

  Future<void> addGachaPull(String quoteId, String rarityId) async {
    final db = await instance.database;
    await db.insert('gacha_pull_history', {
      'quote_id': quoteId,
      'rarity_id': rarityId,
      'pulled_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<GachaPullRecord>> getGachaHistory() async {
    final db = await instance.database;
    final result = await db.query('gacha_pull_history', orderBy: 'pulled_at DESC');
    return result.map((row) => GachaPullRecord(
      quoteId: row['quote_id'] as String,
      rarityId: row['rarity_id'] as String,
      pulledAt: DateTime.parse(row['pulled_at'] as String),
    )).toList();
  }

  // --- Announcement Methods ---

  Future<void> markAnnouncementsAsRead(List<String> announcementIds) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final id in announcementIds) {
      batch.insert('read_announcements', {'id': id}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<Set<String>> getReadAnnouncementIds() async {
    final db = await instance.database;
    final result = await db.query('read_announcements', columns: ['id']);
    return result.map((row) => row['id'] as String).toSet();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
