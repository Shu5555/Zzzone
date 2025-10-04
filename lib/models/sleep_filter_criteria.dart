import 'package:flutter/material.dart';

class SleepFilterCriteria {
  final int? minSleepDurationHours;
  final int? maxSleepDurationHours;
  final bool? hasDrowsiness;
  final bool? hasOverslept;
  final bool? achievedGoal;
  final int? performanceLevel;
  final String? hashtag;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? minSleepScore;
  final int? maxSleepScore;

  SleepFilterCriteria({
    this.minSleepDurationHours,
    this.maxSleepDurationHours,
    this.hasDrowsiness,
    this.hasOverslept,
    this.achievedGoal,
    this.performanceLevel,
    this.hashtag,
    this.startDate,
    this.endDate,
    this.minSleepScore,
    this.maxSleepScore,
  });

  SleepFilterCriteria copyWith({
    int? minSleepDurationHours,
    int? maxSleepDurationHours,
    bool? hasDrowsiness,
    bool? hasOverslept,
    bool? achievedGoal,
    int? performanceLevel,
    String? hashtag,
    DateTime? startDate,
    DateTime? endDate,
    int? minSleepScore,
    int? maxSleepScore,
  }) {
    return SleepFilterCriteria(
      minSleepDurationHours: minSleepDurationHours ?? this.minSleepDurationHours,
      maxSleepDurationHours: maxSleepDurationHours ?? this.maxSleepDurationHours,
      hasDrowsiness: hasDrowsiness ?? this.hasDrowsiness,
      hasOverslept: hasOverslept ?? this.hasOverslept,
      achievedGoal: achievedGoal ?? this.achievedGoal,
      performanceLevel: performanceLevel ?? this.performanceLevel,
      hashtag: hashtag ?? this.hashtag,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minSleepScore: minSleepScore ?? this.minSleepScore,
      maxSleepScore: maxSleepScore ?? this.maxSleepScore,
    );
  }

  bool get isEmpty {
    return minSleepDurationHours == null &&
        maxSleepDurationHours == null &&
        hasDrowsiness == null &&
        hasOverslept == null &&
        achievedGoal == null &&
        performanceLevel == null &&
        hashtag == null &&
        startDate == null &&
        endDate == null &&
        minSleepScore == null &&
        maxSleepScore == null;
  }

  @override
  String toString() {
    return 'SleepFilterCriteria(minSleepDurationHours: $minSleepDurationHours, maxSleepDurationHours: $maxSleepDurationHours, hasDrowsiness: $hasDrowsiness, hasOverslept: $hasOverslept, achievedGoal: $achievedGoal, performanceLevel: $performanceLevel, hashtag: $hashtag, startDate: $startDate, endDate: $endDate, minSleepScore: $minSleepScore, maxSleepScore: $maxSleepScore)';
  }
}