import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement.dart';

class AnnouncementService {
  static const String _lastCheckedAtKey = 'announcements_last_checked_at';

  Future<List<Announcement>> loadAnnouncements() async {
    // 1. アセットからJSONファイルを読み込む
    final String jsonString = await rootBundle.loadString('assets/announcements.json');

    // 2. JSON文字列をデコードしてリストに変換
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    // 3. JSONオブジェクトのリストをAnnouncementオブジェクトのリストに変換
    final List<Announcement> announcements = jsonList
        .map((jsonItem) => Announcement.fromJson(jsonItem as Map<String, dynamic>))
        .toList();

    // 4. createdAtで降順（新しいものが先頭）にソート
    announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return announcements;
  }

  // --- 未読管理機能 ---

  // 最後に確認した日時を取得
  Future<DateTime?> _getLastCheckedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastCheckedAtKey);
    if (timestamp == null) {
      return null;
    }
    return DateTime.parse(timestamp);
  }

  // お知らせを確認した日時を更新
  Future<void> updateLastCheckedAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckedAtKey, DateTime.now().toIso8601String());
  }

  // 未読のお知らせがあるかチェック
  Future<bool> hasUnreadAnnouncements() async {
    final lastCheckedAt = await _getLastCheckedAt();
    final announcements = await loadAnnouncements();

    // お知らせが一つもない場合は未読なし
    if (announcements.isEmpty) {
      return false;
    }

    // まだ一度も確認していない場合は、お知らせがあれば未読あり
    if (lastCheckedAt == null) {
      return true;
    }

    // 最新のお知らせの日時が、最後に確認した日時より後なら未読あり
    final latestAnnouncementDate = announcements.first.createdAt;
    return latestAnnouncementDate.isAfter(lastCheckedAt);
  }
}
