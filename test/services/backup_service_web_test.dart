import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_management_app/models/gacha_pull_record.dart';
import 'package:sleep_management_app/models/sleep_record.dart';
import 'package:sleep_management_app/services/backup_service_web.dart';
import 'package:sleep_management_app/services/database_helper_interface.dart';

import 'mocks.mocks.dart';

void main() {
  group('BackupServiceWeb', () {
    late BackupServiceWeb backupServiceWeb;
    late MockIDatabaseHelper mockDatabaseHelper;

    setUp(() {
      // Use the generated mock for the interface
      mockDatabaseHelper = MockIDatabaseHelper();
      // Inject the mock into the service
      backupServiceWeb = BackupServiceWeb(dbHelper: mockDatabaseHelper);
    });

    test('createBackupJson should return a valid JSON with all data', () async {
      // 1. Arrange
      // Mock SharedPreferences
      final prefsData = {
        'username': 'test_user',
        'sleepGoal': 8.0,
        'isNotificationsEnabled': true,
      };
      SharedPreferences.setMockInitialValues(prefsData);

      // Mock Database Data
      final sleepRecord = SleepRecord(
        dataId: 'test1',
        recordDate: DateTime(2024, 1, 1),
        spec_version: 1,
        sleepTime: DateTime(2024, 1, 1, 22, 0),
        wakeUpTime: DateTime(2024, 1, 2, 6, 0),
        score: 85,
        performance: 4,
        hadDaytimeDrowsiness: false,
        hasAchievedGoal: true,
        memo: 'Good sleep',
        didNotOversleep: true,
      );
      final unlockedQuoteIds = ['quote1', 'quote2'];
      final gachaHistory = [
        GachaPullRecord(quoteId: 'quote1', rarityId: 'common', pulledAt: DateTime(2024, 1, 2, 7, 0)),
      ];
      final readAnnouncements = {'announcement1'};

      // Stub the mock methods
      when(mockDatabaseHelper.readAllRecords()).thenAnswer((_) async => [sleepRecord]);
      when(mockDatabaseHelper.getUnlockedQuoteIds()).thenAnswer((_) async => unlockedQuoteIds);
      when(mockDatabaseHelper.getGachaHistory()).thenAnswer((_) async => gachaHistory);
      when(mockDatabaseHelper.getReadAnnouncementIds()).thenAnswer((_) async => readAnnouncements);

      // 2. Act
      final jsonString = await backupServiceWeb.createBackupJson();

      // 3. Assert
      final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;

      // Check if all keys exist
      expect(decodedJson.containsKey('sleep_records'), isTrue);
      expect(decodedJson.containsKey('unlocked_quotes'), isTrue);
      expect(decodedJson.containsKey('gacha_pull_history'), isTrue);
      expect(decodedJson.containsKey('read_announcements'), isTrue);
      expect(decodedJson.containsKey('shared_preferences'), isTrue);

      // Check content
      expect(decodedJson['sleep_records'], isA<List>());
      expect((decodedJson['sleep_records'] as List).first['dataId'], 'test1');
      expect(decodedJson['unlocked_quotes'], unlockedQuoteIds);
      expect((decodedJson['gacha_pull_history'] as List).first['quote_id'], 'quote1');
      expect(decodedJson['read_announcements'], readAnnouncements.toList());
      expect(decodedJson['shared_preferences']['username'], 'test_user');
    });
    test('restoreFromJson should clear existing data and restore from JSON', () async {
      // 1. Arrange
      final Map<String, dynamic> backupJson = {
        'sleep_records': [
          SleepRecord(
            dataId: 'restored1',
            recordDate: DateTime(2024, 2, 1),
            spec_version: 1,
            sleepTime: DateTime(2024, 2, 1, 23, 0),
            wakeUpTime: DateTime(2024, 2, 2, 7, 0),
            score: 90,
            performance: 5,
            hadDaytimeDrowsiness: false,
            hasAchievedGoal: true,
            memo: 'Restored sleep',
            didNotOversleep: true,
          ).toMap(),
        ],
        'unlocked_quotes': ['quote3', 'quote4'],
        'gacha_pull_history': [
          {
            'quote_id': 'quote3',
            'rarity_id': 'rare',
            'pulled_at': DateTime(2024, 2, 2, 8, 0).toIso8601String(),
          }
        ],
        'read_announcements': ['announcement2'],
        'shared_preferences': {
          'username': 'restored_user',
          'sleepGoal': 7.5,
          'isNotificationsEnabled': false,
          'theme': 'dark',
          'some_int': 123,
          'string_list': ['a', 'b']
        }
      };
      final jsonString = jsonEncode(backupJson);

      // Set initial (pre-restore) SharedPreferences data
      SharedPreferences.setMockInitialValues({'username': 'old_user'});

      // Stub the mock methods that perform writes
      when(mockDatabaseHelper.deleteAllRecords()).thenAnswer((_) async => 1);
      when(mockDatabaseHelper.create(any)).thenAnswer((_) async => Future.value(SleepRecord.fromMap(backupJson['sleep_records']![0])) );
      when(mockDatabaseHelper.addUnlockedQuote(any)).thenAnswer((_) async => true);
      when(mockDatabaseHelper.addGachaPull(any, any)).thenAnswer((_) async => Future.value());
      when(mockDatabaseHelper.markAnnouncementsAsRead(any)).thenAnswer((_) async => Future.value());

      // 2. Act
      await backupServiceWeb.restoreFromJson(jsonString);

      // 3. Assert
      // Verify that data was cleared first
      verify(mockDatabaseHelper.deleteAllRecords()).called(1);
      // Cannot verify SharedPreferences.clear() with this mock setup, but we can check the end result.

      // Verify that data was inserted
      verify(mockDatabaseHelper.create(any)).called(1);
      verify(mockDatabaseHelper.addUnlockedQuote('quote3')).called(1);
      verify(mockDatabaseHelper.addUnlockedQuote('quote4')).called(1);
      verify(mockDatabaseHelper.addGachaPull('quote3', 'rare')).called(1);
      verify(mockDatabaseHelper.markAnnouncementsAsRead(['announcement2'])).called(1);

      // Verify SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('username'), 'restored_user');
      expect(prefs.getDouble('sleepGoal'), 7.5);
      expect(prefs.getBool('isNotificationsEnabled'), false);
      expect(prefs.getString('theme'), 'dark');
      expect(prefs.getInt('some_int'), 123);
      expect(prefs.getStringList('string_list'), ['a', 'b']);
      // Check that old data is gone
      expect(prefs.containsKey('old_user'), isFalse);
    });
  });
}
