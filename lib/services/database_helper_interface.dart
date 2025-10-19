import 'package:sleep_management_app/models/sleep_record.dart';
import 'package:sleep_management_app/models/gacha_pull_record.dart';

abstract class IDatabaseHelper {
  Future<SleepRecord> create(SleepRecord record);
  Future<SleepRecord?> readRecord(String dataId);
  Future<List<SleepRecord>> readAllRecords();
  Future<List<SleepRecord>> readRecordsForLastNDays(int days);
  Future<List<SleepRecord>> readRecordsForMonth(int year, int month);
  Future<int> update(SleepRecord record);
  Future<int> delete(String dataId);
  Future<int> deleteAllRecords();
  Future<SleepRecord?> getLatestRecord();
  Future<List<SleepRecord>> getLatestRecords({int limit = 3});
  Future<SleepRecord?> getRecordForDate(DateTime date);
  Future<bool> addUnlockedQuote(String quoteId);
  Future<List<String>> getUnlockedQuoteIds();
  Future<void> addGachaPull(String quoteId, String rarityId);
  Future<List<GachaPullRecord>> getGachaHistory();
  Future<void> markAnnouncementsAsRead(List<String> announcementIds);
  Future<Set<String>> getReadAnnouncementIds();
  Future<int> deleteAllUnlockedQuotes();
  Future<int> deleteAllGachaHistory();
  Future<int> deleteAllReadAnnouncements();
  Future<void> close();
}
