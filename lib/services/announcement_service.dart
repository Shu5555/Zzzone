import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sleep_management_app/services/database_helper.dart';
import '../models/announcement.dart';

class AnnouncementService {

  Future<List<Announcement>> loadAnnouncements() async {
    final String jsonString = await rootBundle.loadString('assets/announcements.json');
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    final List<Announcement> announcements = jsonList
        .map((jsonItem) => Announcement.fromJson(jsonItem as Map<String, dynamic>))
        .toList();
    announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return announcements;
  }

  // --- 未読管理機能 (新ロジック) ---

  /// お知らせを既読としてマークする
  Future<void> markAnnouncementsAsRead(List<Announcement> announcements) async {
    final ids = announcements.map((a) => a.id).toList();
    await DatabaseHelper.instance.markAnnouncementsAsRead(ids);
  }

  /// 未読のお知らせがあるかチェック
  Future<bool> hasUnreadAnnouncements() async {
    final allAnnouncements = await loadAnnouncements();
    if (allAnnouncements.isEmpty) {
      return false;
    }

    final readAnnouncementIds = await DatabaseHelper.instance.getReadAnnouncementIds();
    
    // １つでも読んでいないお知らせがあればtrueを返す
    return allAnnouncements.any((announcement) => !readAnnouncementIds.contains(announcement.id));
  }

  /// 既読のお知らせIDを取得する（デバッグやテスト用）
  Future<Set<String>> getReadIds() async {
    return await DatabaseHelper.instance.getReadAnnouncementIds();
  }
}