import 'package:flutter/material.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';

class AnalysisReportView extends StatefulWidget {
  const AnalysisReportView({super.key});

  @override
  State<AnalysisReportView> createState() => _AnalysisReportViewState();
}

class _AnalysisReportViewState extends State<AnalysisReportView> {
  Future<Map<String, String>>? _analysisFuture;

  @override
  void initState() {
    super.initState();
    _analysisFuture = _performAnalysis();
  }

  Future<Map<String, String>> _performAnalysis() async {
    final records = await DatabaseHelper.instance.readAllRecords();
    if (records.length < 10) {
      return {'error': '分析するには、少なくとも10件の睡眠記録が必要です。'};
    }

    // 分析ロジック
    final bestDuration = _analyzePerformanceVsDuration(records);
    final scoreCorrelation = _analyzePerformanceVsScore(records);
    final bedtimeImpact = _analyzePerformanceVsBedtime(records);

    return {
      'bestDuration': bestDuration,
      'scoreCorrelation': scoreCorrelation,
      'bedtimeImpact': bedtimeImpact,
    };
  }

  String _analyzePerformanceVsDuration(List<SleepRecord> records) {
    final Map<String, List<int>> performanceDurations = {
      '1': [], // Bad
      '2': [], // Normal
      '3': [], // Good
    };

    for (var record in records) {
      performanceDurations[record.performance.toString()]?.add(record.duration.inMinutes);
    }

    final goodDurations = performanceDurations['3']!;
    if (goodDurations.length < 3) return 'データ不足';

    goodDurations.sort();
    final lowerQuartile = goodDurations[(goodDurations.length * 0.25).floor()];
    final upperQuartile = goodDurations[(goodDurations.length * 0.75).floor()];

    final h1 = (lowerQuartile / 60).floor();
    final m1 = lowerQuartile % 60;
    final h2 = (upperQuartile / 60).floor();
    final m2 = upperQuartile % 60;

    return '${h1}時間${m1}分 ～ ${h2}時間${m2}分';
  }

  String _analyzePerformanceVsScore(List<SleepRecord> records) {
    final highQualityRecords = records.where((r) => r.score >= 8).toList();
    if (highQualityRecords.length < 3) return 'データ不足';

    final goodPerformanceCount = highQualityRecords.where((r) => r.performance == 3).length;
    final percentage = (goodPerformanceCount / highQualityRecords.length) * 100;

    return '${percentage.toStringAsFixed(0)}%';
  }

  String _analyzePerformanceVsBedtime(List<SleepRecord> records) {
    final lateNights = records.where((r) => r.sleepTime.hour >= 1 && r.sleepTime.hour < 4).toList();
    final earlyNights = records.where((r) => r.sleepTime.hour < 1 || r.sleepTime.hour > 21).toList();

    if (lateNights.length < 3 || earlyNights.length < 3) return 'データ不足';

    double avgPerfLate = lateNights.map((r) => r.performance).reduce((a, b) => a + b) / lateNights.length;
    double avgPerfEarly = earlyNights.map((r) => r.performance).reduce((a, b) => a + b) / earlyNights.length;

    if (avgPerfEarly > avgPerfLate) {
      return '午前1時より前に寝た方が良い傾向';
    } else {
      return '就寝時刻による差はあまり見られません';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _analysisFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('分析中にエラーが発生しました: ${snapshot.error}'));
        }

        final results = snapshot.data!;
        if (results.containsKey('error')) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(results['error']!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAnalysisCard(
              title: 'パフォーマンスが最大化する睡眠時間',
              result: results['bestDuration']!,
              icon: Icons.hourglass_bottom_rounded,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildAnalysisCard(
              title: '睡眠スコア8点以上でパフォーマンスが良かった確率',
              result: results['scoreCorrelation']!,
              icon: Icons.star_rounded,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            _buildAnalysisCard(
              title: '就寝時刻とパフォーマンスの関係',
              result: results['bedtimeImpact']!,
              icon: Icons.bedtime_rounded,
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalysisCard({required String title, required String result, required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                result,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
