import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/gacha_pull_record.dart';
import '../models/sleep_record.dart';
import '../utils/date_helper.dart';
import 'database_helper_interface.dart';

class DatabaseHelper implements IDatabaseHelper {
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

    // DBバージョンを6に更新
    return await openDatabase(path, version: 6, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    await _createSleepRecordsTable(db);
    await _createUnlockedQuotesTable(db);
    await _createGachaPullHistoryTable(db);
    await _createReadAnnouncementsTable(db);
    // 新しいテーブル作成処理を呼び出し
    await _createGachaDataTables(db);
    // 作成したテーブルにデータを投入
    await _populateGachaDataFromAssets(db);
  }

  Future<void> _createSleepRecordsTable(Database db) async {
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

  Future<void> _createUnlockedQuotesTable(Database db) async {
    await db.execute('''
CREATE TABLE unlocked_quotes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id TEXT NOT NULL UNIQUE,
  unlocked_at TEXT NOT NULL
)
''');
  }

  Future<void> _createGachaPullHistoryTable(Database db) async {
    await db.execute('''
CREATE TABLE gacha_pull_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id TEXT NOT NULL,
  rarity_id TEXT NOT NULL,
  pulled_at TEXT NOT NULL
)
''');
  }

  Future<void> _createReadAnnouncementsTable(Database db) async {
    await db.execute('''
CREATE TABLE read_announcements (
  id TEXT PRIMARY KEY
)
''');
  }

  // ▼▼▼ ここからが新しいコード ▼▼▼

  // ガチャデータ（レアリティ、名言）を格納するテーブルを作成
  Future<void> _createGachaDataTables(Database db) async {
    await db.execute('''
    CREATE TABLE rarities (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color TEXT NOT NULL,
      "order" INTEGER NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE quotes (
      id TEXT PRIMARY KEY,
      rarity_id TEXT NOT NULL,
      author TEXT NOT NULL,
      quote TEXT NOT NULL,
      FOREIGN KEY (rarity_id) REFERENCES rarities (id)
    )
    ''');
  }

  // JSONアセットからガチャデータを読み込み、DBに格納する
  Future<void> _populateGachaDataFromAssets(Database db) async {
    // raritiesテーブルが空の場合のみデータを投入
    final rarityCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM rarities'));
    if (rarityCount == 0) {
      final String configJsonString = await rootBundle.loadString('assets/gacha/gacha_config.json');
      final configData = json.decode(configJsonString);
      final raritiesData = configData['rarities'] as List;

      final batch = db.batch();
      for (var rarity in raritiesData) {
        batch.insert('rarities', {
          'id': rarity['id'],
          'name': rarity['name'],
          'color': rarity['color'],
          'order': rarity['order'],
        });
      }
      await batch.commit(noResult: true);
    }

    // quotesテーブルが空の場合のみデータを投入
    final quoteCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM quotes'));
    if (quoteCount == 0) {
      final String itemsJsonString = await rootBundle.loadString('assets/gacha/gacha_items.json');
      final itemsData = json.decode(itemsJsonString);
      final quotesData = itemsData['items'] as List;

      final batch = db.batch();
      for (var item in quotesData) {
        batch.insert('quotes', {
          'id': item['id'],
          'rarity_id': item['rarityId'],
          'author': item['customData']['author'],
          'quote': item['customData']['text'],
        });
      }
      await batch.commit(noResult: true);
    }
  }

  // 名言一覧画面用に、JOINして全ての情報を取得する高効率メソッド
  Future<List<Map<String, dynamic>>> getUnlockedQuotesWithDetails() async {
    final db = await instance.database;
    const query = '''
    SELECT
      q.id,
      q.quote,
      q.author,
      r.id as rarityId,
      r.name as rarityName,
      r.color as rarityColor,
      r."order" as rarityOrder
    FROM unlocked_quotes uq
    JOIN quotes q ON uq.quote_id = q.id
    JOIN rarities r ON q.rarity_id = r.id
    ORDER BY r."order" DESC, q.author ASC
    ''';
    final result = await db.rawQuery(query);
    return result;
  }

  // ▲▲▲ ここまでが新しいコード ▲▲▲

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 省略
    }
    if (oldVersion < 3) {
      await _createUnlockedQuotesTable(db);
    }
    if (oldVersion < 4) {
      await _createGachaPullHistoryTable(db);
    }
    if (oldVersion < 5) {
      await _createReadAnnouncementsTable(db);
    }
    if (oldVersion < 6) {
      // DBバージョン6へのアップグレード時に新しいテーブルを作成しデータを投入
      await _createGachaDataTables(db);
      await _populateGachaDataFromAssets(db);
    }
  }

  // --- SleepRecord Methods ---
  // ... 以下、既存のメソッド群 (変更なし) ...

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

  Future<List<SleepRecord>> readRecordsForLastNDays(int days) async {
    final db = await instance.database;
    final today = getLogicalDate(DateTime.now());
    final startDate = today.subtract(Duration(days: days - 1));
    final startDateString = startDate.toIso8601String().substring(0, 10);

    final result = await db.query(
      'sleep_records',
      where: 'recordDate >= ?',
      whereArgs: [startDateString],
      orderBy: 'recordDate DESC, wakeUpTime DESC',
    );
    return result.map((json) => SleepRecord.fromMap(json)).toList();
  }

  Future<List<SleepRecord>> readRecordsForMonth(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final yearMonthStr = '$year-$monthStr';

    final result = await db.query(
      'sleep_records',
      where: 'recordDate LIKE ?',
      whereArgs: ['$yearMonthStr%'],
      orderBy: 'recordDate DESC, wakeUpTime DESC',
    );
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

  Future<int> deleteAllUnlockedQuotes() async {
    final db = await instance.database;
    return await db.delete('unlocked_quotes');
  }

  Future<int> deleteAllGachaHistory() async {
    final db = await instance.database;
    return await db.delete('gacha_pull_history');
  }

  Future<int> deleteAllReadAnnouncements() async {
    final db = await instance.database;
    return await db.delete('read_announcements');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
