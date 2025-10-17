import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sleep_management_app/services/supabase_ranking_service.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import '../services/cache_service.dart';
import '../services/analysis_service.dart';
import '../utils/date_helper.dart';

enum ReportState { loading, success, error, noData }

class AnalysisReportScreen extends StatefulWidget {
  const AnalysisReportScreen({super.key});

  @override
  State<AnalysisReportScreen> createState() => _AnalysisReportViewState();
}

class _AnalysisReportViewState extends State<AnalysisReportScreen> {
  final _supabase = Supabase.instance.client;
  ReportState _state = ReportState.loading;
  String _message = '分析データを読み込んでいます...';

  Map<String, dynamic>? _llmAnalysisResult;
  Map<String, dynamic>? _localAnalysisResult;

  @override
  void initState() {
    super.initState();
    _triggerAnalysisCheck();
  }

  Future<void> _saveScoreToSupabase(int score, String userId) async {
    try {
      final dateString = getLogicalDateString(DateTime.now());
      await _supabase.from('ai_score_ranking').upsert({
        'user_id': userId,
        'score': score,
        'recorded_date': dateString,
      }, onConflict: 'user_id, recorded_date');
    } catch (e) {
      // ignore: avoid_print
      print('--- Score Save Error ---');
      // ignore: avoid_print
      print('Failed to save score from widget: $e');
      // Here you could show a non-blocking snackbar to the user
      // For example: ScaffoldMessenger.of(context).showSnackBar(...);
    }
  }

  Future<void> _triggerAnalysisCheck() async {
    // 1. Get User Preferences
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    String aiTone = 'default';
    String aiGender = 'unspecified';

    if (userId != null) {
      final userProfile = await SupabaseRankingService().getUser(userId);
      if (userProfile != null) {
        aiTone = userProfile['ai_tone'] ?? 'default';
        aiGender = userProfile['ai_gender_preference'] ?? 'unspecified';
      }
    }

    // 2. Check record count
    final records = await DatabaseHelper.instance.getLatestRecords(limit: 30);
    if (records.length < 5) {
      if (mounted) setState(() {
        _state = ReportState.noData;
        _message = '分析には5件以上の睡眠記録が必要です。';
      });
      return;
    }

    // 3. Perform local analysis
    final localResult = _performLocalAnalysis(records);

    // 4. LLM Analysis (Cache check & API call)
    final cacheService = CacheService();
    final cachedData = await cacheService.loadAnalysis();
    final currentLatestRecordDataId = records.first.dataId;

    // 4a. Check for a recent failure
    if (cachedData?.failureTimestamp != null) {
      final timeSinceFailure = DateTime.now().difference(cachedData!.failureTimestamp!);
      if (timeSinceFailure.inMinutes < 1) {
        if (mounted) setState(() {
          _state = ReportState.error;
          _message = '分析APIの呼び出しが連続で失敗しました。\n1分ほど時間をおいてから、再度お試しください。';
        });
        return; // Abort the API call
      }
    }

    // 4b. Check for a valid success cache
    if (cachedData?.analysisResult != null && cachedData?.latestRecordId == currentLatestRecordDataId) {
      if (mounted) setState(() {
        _llmAnalysisResult = cachedData!.analysisResult;
        _localAnalysisResult = localResult;
        _state = ReportState.success;
      });
    } else {
      // 4c. Fetch from API
      try {
        if (userId == null) {
          throw Exception('ユーザーIDが取得できませんでした。再ログインしてください。');
        }
        
        // Fetch analysis from the simplified service
        final newLlmResult = await AnalysisService().fetchSleepAnalysis(records, aiTone, aiGender);

        // Save the score here, where auth context is guaranteed
        if (newLlmResult.containsKey('overall_score')) {
          final score = newLlmResult['overall_score'] as int;
          await _saveScoreToSupabase(score, userId);
        }

        // Save the successful result to cache
        await cacheService.saveAnalysis(newLlmResult, currentLatestRecordDataId);
        
        if (mounted) setState(() {
          _llmAnalysisResult = newLlmResult;
          _localAnalysisResult = localResult;
          _state = ReportState.success;
        });

      } catch (e) {
        // On failure, save a failure timestamp to prevent rapid retries
        await cacheService.saveFailure();
        if (mounted) setState(() {
          _state = ReportState.error;
          _message = '分析データの取得に失敗しました。\n時間をおいて再度お試しください。\nError: ${e.toString()}';
        });
      }
    }
  }

  // --- Local Analysis Logic (unchanged) ---
  Map<String, dynamic> _performLocalAnalysis(List<SleepRecord> records) {
    return {
      'bestDuration': _analyzePerformanceVsDuration(records),
      'scoreCorrelation': _analyzePerformanceVsScore(records),
      'bedtimeImpact': _analyzePerformanceVsBedtime(records),
      'scorePatterns': _analyzeScorePatterns(records),
      'achievements': _calculateAchievements(records),
    };
  }

  List<String> _calculateAchievements(List<SleepRecord> records) {
    List<String> achievements = [];
    int highScoreStreak = 0, goalStreak = 0, longSleepStreak = 0, recordingStreak = 0;

    for (var record in records) {
      if (record.score >= 8) highScoreStreak++; else break;
    }
    if (highScoreStreak >= 2) achievements.add('高スコア（8点以上）を $highScoreStreak 日連続で達成中！');

    for (var record in records) {
      if (record.hasAchievedGoal) goalStreak++; else break;
    }
    if (goalStreak >= 2) achievements.add('目標達成を $goalStreak 日連続で継続中！');

    for (var record in records) {
      if (record.duration.inHours >= 7) longSleepStreak++; else break;
    }
    if (longSleepStreak >= 2) achievements.add('7時間以上の睡眠を $longSleepStreak 日連続で達成中！');

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
    if (recordingStreak >= 3) achievements.add('$recordingStreak 日間、毎日記録を継続中！');

    return achievements;
  }

  String _analyzePerformanceVsDuration(List<SleepRecord> records) {
    final performanceDurations = <String, List<int>>{'1': [], '2': [], '3': []};
    for (var r in records) { performanceDurations[r.performance.toString()]?.add(r.duration.inMinutes); }
    final goodDurations = performanceDurations['3']!;
    if (goodDurations.length < 3) return 'データ不足';
    goodDurations.sort();
    final lower = goodDurations[(goodDurations.length * 0.25).floor()];
    final upper = goodDurations[(goodDurations.length * 0.75).floor()];
    return '${(lower / 60).floor()}時間${lower % 60}分 ～ ${(upper / 60).floor()}時間${upper % 60}分';
  }

  String _analyzePerformanceVsScore(List<SleepRecord> records) {
    final highQuality = records.where((r) => r.score >= 8).toList();
    if (highQuality.length < 3) return 'データ不足';
    final goodPerfCount = highQuality.where((r) => r.performance == 3).length;
    return '${(goodPerfCount / highQuality.length * 100).toStringAsFixed(0)}%';
  }

  String _analyzePerformanceVsBedtime(List<SleepRecord> records) {
    final lateNights = records.where((r) => r.sleepTime.hour >= 1 && r.sleepTime.hour < 4).toList();
    final earlyNights = records.where((r) => r.sleepTime.hour < 1 || r.sleepTime.hour > 21).toList();
    if (lateNights.length < 3 || earlyNights.length < 3) return 'データ不足';
    double avgPerfLate = lateNights.map((r) => r.performance).reduce((a, b) => a + b) / lateNights.length;
    double avgPerfEarly = earlyNights.map((r) => r.performance).reduce((a, b) => a + b) / earlyNights.length;
    return avgPerfEarly > avgPerfLate ? '午前1時より前に寝た方が良い傾向' : '就寝時刻による差はあまり見られません';
  }

  Map<String, double> _analyzeScorePatterns(List<SleepRecord> records) {
    double avg(List<SleepRecord> list) => list.isEmpty ? 0.0 : list.map((r) => r.score).reduce((a, b) => a + b) / list.length;
    return {
      'achieved': avg(records.where((r) => r.hasAchievedGoal).toList()),
      'notAchieved': avg(records.where((r) => !r.hasAchievedGoal).toList()),
      'noOversleep': avg(records.where((r) => r.didNotOversleep).toList()),
      'overslept': avg(records.where((r) => !r.didNotOversleep).toList()),
    };
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case ReportState.loading:
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(_message, style: Theme.of(context).textTheme.titleMedium)]));
      case ReportState.noData:
      case ReportState.error:
        return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text(_message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)));
      case ReportState.success:
        if (_llmAnalysisResult == null || _localAnalysisResult == null) return const Center(child: Text('予期せぬエラーが発生しました。'));
        
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildOverallScoreCard(),
            const SizedBox(height: 16),
            _buildSectionCard(context, title: 'AIによる総評', icon: Icons.comment_rounded, color: Colors.blue, content: Text(_llmAnalysisResult!['overall_comment'] as String? ?? 'コメントはありません。', style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5))),
            const SizedBox(height: 16),
            _buildSectionCard(context, title: 'AIが見つけた良い点', icon: Icons.thumb_up_rounded, color: Colors.green, content: _buildPointList(_llmAnalysisResult!['positive_points'] as List<dynamic>? ?? [])),
            const SizedBox(height: 16),
            _buildSectionCard(context, title: 'AIによる改善提案', icon: Icons.lightbulb_rounded, color: Colors.orange, content: _buildPointList(_llmAnalysisResult!['improvement_suggestions'] as List<dynamic>? ?? [])),
            
            const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider()),

            _buildAchievementsCard(_localAnalysisResult!['achievements'] as List<String>),
            const SizedBox(height: 16),
            _buildAnalysisCard(title: 'パフォーマンスが最大化する睡眠時間', result: _localAnalysisResult!['bestDuration']!, icon: Icons.hourglass_bottom_rounded, color: Colors.blue),
            const SizedBox(height: 16),
            _buildAnalysisCard(title: '睡眠スコア8点以上でパフォーマンスが良かった確率', result: _localAnalysisResult!['scoreCorrelation']!, icon: Icons.star_rounded, color: Colors.amber),
            const SizedBox(height: 16),
            _buildAnalysisCard(title: '就寝時刻とパフォーマンスの関係', result: _localAnalysisResult!['bedtimeImpact']!, icon: Icons.bedtime_rounded, color: Colors.purple),
            const SizedBox(height: 16),
            _buildScoreAnalysisCard(_localAnalysisResult!['scorePatterns'] as Map<String, double>),
          ],
        );
    }
  }

  // --- UI Helper methods ---
  Widget _buildOverallScoreCard() {
    final score = _llmAnalysisResult?['overall_score'];
    final reason = _llmAnalysisResult?['overall_score_reason'] as String?;

    if (score == null || score is! int) {
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
            Row(children: [
              Icon(Icons.auto_awesome, color: Colors.deepPurple.shade300, size: 28),
              const SizedBox(width: 12),
              Text('AIによる総合得点', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: CustomPaint(
                  painter: _DonutChartPainter(score: score.toDouble(), maxScore: 100),
                  child: Center(
                    child: Text(
                      score.toString(),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (reason != null && reason.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPointList(List<dynamic> points) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: points.map((point) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('・ ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Expanded(child: Text(point as String, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4)))]))).toList());
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required Color color, required Widget content}) {
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: color, size: 28), const SizedBox(width: 12), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]), const SizedBox(height: 16), content])));
  }

  Widget _buildAchievementsCard(List<String> achievements) {
    if (achievements.isEmpty) return const SizedBox.shrink();
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.emoji_events_rounded, color: Colors.orange, size: 28), const SizedBox(width: 12), Text('実績・トロフィー', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]), const SizedBox(height: 12), ...achievements.map((text) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Row(children: [const Text('🏆', style: TextStyle(fontSize: 18)), const SizedBox(width: 10), Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge))])))])));
  }

  Widget _buildAnalysisCard({required String title, required String result, required IconData icon, required Color color}) {
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: color, size: 28), const SizedBox(width: 12), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)))]), const SizedBox(height: 16), Center(child: Text(result, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold)))])));
  }

  Widget _buildScoreAnalysisCard(Map<String, double> scores) {
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.analytics_rounded, color: Colors.green, size: 28), const SizedBox(width: 12), Text('スコア分析', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]), const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildAnalysisItem('目標達成時', scores['achieved']!), _buildAnalysisItem('未達成時', scores['notAchieved']!), _buildAnalysisItem('二度寝なし', scores['noOversleep']!), _buildAnalysisItem('二度寝あり', scores['overslept']!)])])));
  }

  Widget _buildAnalysisItem(String label, double score) {
    return Column(children: [Text(label, style: Theme.of(context).textTheme.bodyMedium), Text(score > 0 ? score.toStringAsFixed(1) : '-', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]);
  }
}

class _DonutChartPainter extends CustomPainter {
  final double score;
  final double maxScore;

  _DonutChartPainter({required this.score, required this.maxScore});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final Paint foregroundPaint = Paint()
      ..color = Colors.deepPurple.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);

    canvas.drawCircle(center, radius, backgroundPaint);

    final double sweepAngle = 2 * math.pi * (score / maxScore);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from the top
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}