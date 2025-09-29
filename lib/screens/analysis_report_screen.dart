import 'package:flutter/material.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import '../utils/date_helper.dart';

class AnalysisReportView extends StatefulWidget {
  const AnalysisReportView({super.key});

  @override
  State<AnalysisReportView> createState() => _AnalysisReportViewState();
}

class _AnalysisReportViewState extends State<AnalysisReportView> {
  Future<Map<String, dynamic>>? _analysisFuture;

  @override
  void initState() {
    super.initState();
    _analysisFuture = _performAnalysis();
  }

  Future<Map<String, dynamic>> _performAnalysis() async {
    final records = await DatabaseHelper.instance.readAllRecords();
    if (records.length < 5) { // 実績表示のため、5件に緩和
      return {'error': '分析するには、少なくとも5件の睡眠記録が必要です。'};
    }

    // 分析ロジック
    final bestDuration = _analyzePerformanceVsDuration(records);
    final scoreCorrelation = _analyzePerformanceVsScore(records);
    final bedtimeImpact = _analyzePerformanceVsBedtime(records);
    final scorePatterns = _analyzeScorePatterns(records);
    final achievements = _calculateAchievements(records);

    return {
      'bestDuration': bestDuration,
      'scoreCorrelation': scoreCorrelation,
      'bedtimeImpact': bedtimeImpact,
      'scorePatterns': scorePatterns,
      'achievements': achievements,
    };
  }

  List<String> _calculateAchievements(List<SleepRecord> records) {
    List<String> achievements = [];
    // recordsはsleepTimeの降順でソートされている前提

    // 高スコアストリーク
    int highScoreStreak = 0;
    for (var record in records) {
      if (record.score >= 8) {
        highScoreStreak++;
      } else {
        break;
      }
    }
    if (highScoreStreak >= 2) {
      achievements.add('高スコア（8点以上）を $highScoreStreak 日連続で達成中！');
    }

    // 目標達成ストリーク
    int goalStreak = 0;
    for (var record in records) {
      if (record.hasAchievedGoal) {
        goalStreak++;
      } else {
        break;
      }
    }
    if (goalStreak >= 2) {
      achievements.add('目標達成を $goalStreak 日連続で継続中！');
    }

    // 7時間睡眠ストリーク
    int longSleepStreak = 0;
    for (var record in records) {
      if (record.duration.inHours >= 7) {
        longSleepStreak++;
      } else {
        break;
      }
    }
    if (longSleepStreak >= 2) {
      achievements.add('7時間以上の睡眠を $longSleepStreak 日連続で達成中！');
    }
    
    // 連続記録日数
    int recordingStreak = 0;
    if (records.isNotEmpty) {
        recordingStreak = 1;
        DateTime lastDate = getLogicalDate(records.first.sleepTime);
        for (int i = 1; i < records.length; i++) {
            DateTime currentDate = getLogicalDate(records[i].sleepTime);
            if (lastDate.difference(currentDate).inDays == 1) {
                recordingStreak++;
                lastDate = currentDate;
            } else {
                break;
            }
        }
    }
    if (recordingStreak >= 3) {
        achievements.add('$recordingStreak 日間、毎日記録を継続中！');
    }

    return achievements;
  }

  String _analyzePerformanceVsDuration(List<SleepRecord> records) {
    final Map<String, List<int>> performanceDurations = {
      '1': [], '2': [], '3': [],
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

  Map<String, double> _analyzeScorePatterns(List<SleepRecord> records) {
    double calculateAverageScore(List<SleepRecord> list) {
      if (list.isEmpty) return 0.0;
      return list.map((r) => r.score).reduce((a, b) => a + b) / list.length;
    }
    final achievedRecords = records.where((r) => r.hasAchievedGoal).toList();
    final notAchievedRecords = records.where((r) => !r.hasAchievedGoal).toList();
    final didNotOversleepRecords = records.where((r) => r.didNotOversleep).toList();
    final oversleptRecords = records.where((r) => !r.didNotOversleep).toList();

    return {
      'achieved': calculateAverageScore(achievedRecords),
      'notAchieved': calculateAverageScore(notAchievedRecords),
      'noOversleep': calculateAverageScore(didNotOversleepRecords),
      'overslept': calculateAverageScore(oversleptRecords),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
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
            _buildAchievementsCard(results['achievements'] as List<String>),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            _buildScoreAnalysisCard(results['scorePatterns'] as Map<String, double>),
          ],
        );
      },
    );
  }
  
  Widget _buildAchievementsCard(List<String> achievements) {
    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }
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
                const Icon(Icons.emoji_events_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Text('実績・トロフィー', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...achievements.map((text) => Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
                ],
              ),
            )),
          ],
        ),
      ),
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

  Widget _buildScoreAnalysisCard(Map<String, double> scores) {
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
                const Icon(Icons.analytics_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Text('スコア分析', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnalysisItem('目標達成時', scores['achieved']!),
                _buildAnalysisItem('未達成時', scores['notAchieved']!),
                _buildAnalysisItem('二度寝なし', scores['noOversleep']!),
                _buildAnalysisItem('二度寝あり', scores['overslept']!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(String label, double score) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          score > 0 ? score.toStringAsFixed(1) : '-',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
