class AnalysisCache {
  final Map<String, dynamic> analysisResult;
  final DateTime timestamp;
  final String latestRecordId; // 分析対象のうち、最も新しい睡眠記録のID

  AnalysisCache({
    required this.analysisResult,
    required this.timestamp,
    required this.latestRecordId, // 変更
  });

  // fromJson, toJson も latestRecordId を含めるように更新
  factory AnalysisCache.fromJson(Map<String, dynamic> json) {
    return AnalysisCache(
      analysisResult: Map<String, dynamic>.from(json['analysisResult']),
      timestamp: DateTime.parse(json['timestamp']),
      latestRecordId: json['latestRecordId'] as String, // 変更
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysisResult': analysisResult,
      'timestamp': timestamp.toIso8601String(),
      'latestRecordId': latestRecordId,
    };
  }
}
