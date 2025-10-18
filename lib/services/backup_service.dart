import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  static const _dbFileName = 'sleep.db';
  static const _prefsFileName = 'zzzone_prefs_backup.json';
  static const _zipFileName = 'zzzone_backup.zip';

  /// Returns a list of files to be backed up.
  /// This includes the main database and a temporary file for shared_preferences.
  Future<List<File>> getFilesToBackup() async {
    final List<File> files = [];
    final tempDir = await getTemporaryDirectory();

    // 1. Get database file
    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, _dbFileName));
    if (await dbFile.exists()) {
      files.add(dbFile);
    }

    // 2. Create a temporary file for shared_preferences
    final prefs = await SharedPreferences.getInstance();
    final prefsMap = <String, dynamic>{};
    for (String key in prefs.getKeys()) {
      prefsMap[key] = prefs.get(key);
    }
    final prefsJson = jsonEncode(prefsMap);
    final prefsFile = File(p.join(tempDir.path, _prefsFileName));
    await prefsFile.writeAsString(prefsJson);
    files.add(prefsFile);

    return files;
  }

  /// Creates a zip archive from a list of files.
  /// Returns the path to the created zip file.
  Future<String> createBackupZip(List<File> files) async {
    final tempDir = await getTemporaryDirectory();
    final zipPath = p.join(tempDir.path, _zipFileName);
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    for (final file in files) {
      await encoder.addFile(file);
    }

    encoder.close();
    return zipPath;
  }

  /// Restores files from a zip archive.
  Future<void> restoreFromZip(String zipPath) async {
    final tempDir = await getTemporaryDirectory();
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);

    // Restore files
    for (final file in archive.files) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        if (filename == _dbFileName) {
          final dbPath = await getDatabasesPath();
          final dbFile = File(p.join(dbPath, _dbFileName));
          await dbFile.writeAsBytes(data);
        } else if (filename == _prefsFileName) {
          final prefsFile = File(p.join(tempDir.path, _prefsFileName));
          await prefsFile.writeAsBytes(data);
          // Now, restore shared_preferences from this json file
          final prefsJson = await prefsFile.readAsString();
          final Map<String, dynamic> prefsMap = jsonDecode(prefsJson);
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          for (final key in prefsMap.keys) {
            final value = prefsMap[key];
            // SharedPreferences only supports specific types
            if (value is bool) {
              await prefs.setBool(key, value);
            } else if (value is int) {
              await prefs.setInt(key, value);
            } else if (value is double) {
              await prefs.setDouble(key, value);
            } else if (value is String) {
              await prefs.setString(key, value);
            } else if (value is List<String>) {
              await prefs.setStringList(key, value);
            }
          }
        }
      }
    }
  }
}
