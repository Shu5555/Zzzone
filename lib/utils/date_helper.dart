import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 睡眠記録が属する「論理的な日付」を取得します。
///
/// 一日の区切りは午前4時です。
/// 例えば、入眠時刻が 9/29 02:00 の場合、この記録は 9/28 の睡眠として扱われます。
DateTime getLogicalDate(DateTime dateTime) {
  final localDateTime = dateTime.toLocal();
  DateTime logicalDate = localDateTime.hour < 4
      ? localDateTime.subtract(const Duration(days: 1))
      : localDateTime;
  return DateUtils.dateOnly(logicalDate);
}

/// 睡眠記録が属する「論理的な日付」を YYYY-MM-DD 形式の文字列で取得します。
/// API通信での利用を想定しています。
String getLogicalDateString(DateTime dateTime) {
  final logicalDate = getLogicalDate(dateTime);
  return DateFormat('yyyy-MM-dd').format(logicalDate);
}

/// 「ぐっすりサタデー」の対象期間（金曜 AM4:00 ～ 土曜 AM3:59）であるかを判定します。
bool isSaturday(DateTime date) {
  // 金曜日かつ午前4時以降
  if (date.weekday == DateTime.friday && date.hour >= 4) {
    return true;
  }
  // 土曜日かつ午前4時より前
  if (date.weekday == DateTime.saturday && date.hour < 4) {
    return true;
  }
  return false;
}
