import '../models/sleep_record.dart';

// サポートされていないプラットフォーム用のスタブ
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  Future<SleepRecord> create(SleepRecord record) => throw UnsupportedError('Platform not supported');
  Future<SleepRecord?> readRecord(int id) => throw UnsupportedError('Platform not supported');
  Future<List<SleepRecord>> readAllRecords() => throw UnsupportedError('Platform not supported');
  Future<int> update(SleepRecord record) => throw UnsupportedError('Platform not supported');
  Future<int> delete(int id) => throw UnsupportedError('Platform not supported');
  Future<SleepRecord?> getLatestRecord() => throw UnsupportedError('Platform not supported');
  Future<List<SleepRecord>> getLatestRecords({int limit = 3}) => throw UnsupportedError('Platform not supported');
  Future close() => throw UnsupportedError('Platform not supported');
}
