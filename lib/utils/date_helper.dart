import 'package:flutter/material.dart';

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
