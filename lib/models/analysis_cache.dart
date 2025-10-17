class AnalysisCache {
  final Map<String, dynamic>? analysisResult;
  final DateTime timestamp;
  final String? latestRecordId; // 分析対象のうち、最も新しい睡眠記録のID
  final DateTime? failureTimestamp; // API呼び出しが最後に失敗した日時

  AnalysisCache({
    this.analysisResult,
    required this.timestamp,
    this.latestRecordId,
    this.failureTimestamp,
  });

  factory AnalysisCache.fromJson(Map<String, dynamic> json) {
    return AnalysisCache(
      analysisResult: json['analysisResult'] != null
          ? Map<String, dynamic>.from(json['analysisResult'])
          : null,
      timestamp: DateTime.parse(json['timestamp']),
      latestRecordId: json['latestRecordId'] as String?,
      failureTimestamp: json['failureTimestamp'] != null
          ? DateTime.parse(json['failureTimestamp'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysisResult': analysisResult,
      'timestamp': timestamp.toIso8601String(),
      'latestRecordId': latestRecordId,
      'failureTimestamp': failureTimestamp?.toIso8601String(),
    };
  }
}