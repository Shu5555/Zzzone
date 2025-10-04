class SleepRecord {
  final String dataId;
  final DateTime recordDate;
  final int spec_version;

  final DateTime sleepTime;
  final DateTime wakeUpTime;
  final int score;
  final int performance;
  final bool hadDaytimeDrowsiness;
  final bool hasAchievedGoal;
  final String? memo;
  final bool didNotOversleep;

  Duration get duration => wakeUpTime.difference(sleepTime);

  SleepRecord({
    required this.dataId,
    required this.recordDate,
    this.spec_version = 2,
    required this.sleepTime,
    required this.wakeUpTime,
    required this.score,
    required this.performance,
    required this.hadDaytimeDrowsiness,
    required this.hasAchievedGoal,
    this.memo,
    required this.didNotOversleep,
  });

  SleepRecord copyWith({
    String? dataId,
    DateTime? recordDate,
    int? spec_version,
    DateTime? sleepTime,
    DateTime? wakeUpTime,
    int? score,
    int? performance,
    bool? hadDaytimeDrowsiness,
    bool? hasAchievedGoal,
    String? memo,
    bool? didNotOversleep,
  }) {
    return SleepRecord(
      dataId: dataId ?? this.dataId,
      recordDate: recordDate ?? this.recordDate,
      spec_version: spec_version ?? this.spec_version,
      sleepTime: sleepTime ?? this.sleepTime,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      score: score ?? this.score,
      performance: performance ?? this.performance,
      hadDaytimeDrowsiness: hadDaytimeDrowsiness ?? this.hadDaytimeDrowsiness,
      hasAchievedGoal: hasAchievedGoal ?? this.hasAchievedGoal,
      memo: memo ?? this.memo,
      didNotOversleep: didNotOversleep ?? this.didNotOversleep,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dataId': dataId,
      'recordDate': recordDate.toIso8601String(),
      'spec_version': spec_version,
      'sleepTime': sleepTime.toIso8601String(),
      'wakeUpTime': wakeUpTime.toIso8601String(),
      'score': score,
      'performance': performance,
      'hadDaytimeDrowsiness': hadDaytimeDrowsiness ? 1 : 0,
      'hasAchievedGoal': hasAchievedGoal ? 1 : 0,
      'memo': memo,
      'didNotOversleep': didNotOversleep ? 1 : 0,
    };
  }

  factory SleepRecord.fromMap(Map<String, dynamic> map) {
    return SleepRecord(
      dataId: map['dataId'],
      recordDate: DateTime.parse(map['recordDate']),
      spec_version: map['spec_version'] ?? 2,
      sleepTime: DateTime.parse(map['sleepTime']),
      wakeUpTime: DateTime.parse(map['wakeUpTime']),
      score: map['score'],
      performance: map['performance'],
      hadDaytimeDrowsiness: map['hadDaytimeDrowsiness'] == 1,
      hasAchievedGoal: map['hasAchievedGoal'] == 1,
      memo: map['memo'],
      didNotOversleep: map['didNotOversleep'] == 1,
    );
  }

  Map<String, dynamic> toMapForAnalysis() {
    return {
      'sleepTime': sleepTime.toIso8601String(),
      'durationInMinutes': duration.inMinutes,
      'score': score,
      'performance': performance,
      'memo': memo,
    };
  }
}
