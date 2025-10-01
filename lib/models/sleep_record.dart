class SleepRecord {
  final int? id;
  final DateTime sleepTime;
  final DateTime wakeUpTime;
  final int score;
  final int performance;
  final bool hadDaytimeDrowsiness;
  final bool hasAchievedGoal;
  final String? memo;
  final bool didNotOversleep; // 追加

  Duration get duration => wakeUpTime.difference(sleepTime);

  SleepRecord({
    this.id,
    required this.sleepTime,
    required this.wakeUpTime,
    required this.score,
    required this.performance,
    required this.hadDaytimeDrowsiness,
    required this.hasAchievedGoal,
    this.memo,
    required this.didNotOversleep, // 追加
  });

  SleepRecord copyWith({
    int? id,
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
      id: id ?? this.id,
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
      'id': id,
      'sleepTime': sleepTime.toUtc().toIso8601String(),
      'wakeUpTime': wakeUpTime.toUtc().toIso8601String(),
      'score': score,
      'performance': performance,
      'hadDaytimeDrowsiness': hadDaytimeDrowsiness ? 1 : 0,
      'hasAchievedGoal': hasAchievedGoal ? 1 : 0,
      'memo': memo,
      'didNotOversleep': didNotOversleep ? 1 : 0, // 追加
    };
  }

  factory SleepRecord.fromMap(Map<String, dynamic> map) {
    return SleepRecord(
      id: map['id'],
      sleepTime: DateTime.parse(map['sleepTime']),
      wakeUpTime: DateTime.parse(map['wakeUpTime']),
      score: map['score'],
      performance: map['performance'],
      hadDaytimeDrowsiness: map['hadDaytimeDrowsiness'] == 1,
      hasAchievedGoal: map['hasAchievedGoal'] == 1,
      memo: map['memo'],
      didNotOversleep: map['didNotOversleep'] == 1, // 追加
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
