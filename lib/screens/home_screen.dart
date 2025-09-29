import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import 'post_sleep_input_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSleeping = false;
  DateTime? _sleepStartTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String _dailyQuote = '';
  String _dailyQuoteAuthor = '';

  @override
  void initState() {
    super.initState();
    _updateTopArea();
  }

  Future<void> _updateTopArea() async {
    try {
      // デフォルトで名言をセット
      final String jsonString = await rootBundle.loadString('assets/data/quotes.json');
      final List<dynamic> quotesList = jsonDecode(jsonString);

      // 1日の区切りを午前4時にするため、4時より前は前日の日付として扱う
      final now = DateTime.now();
      final effectiveDate = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
      final dayOfYear = effectiveDate.difference(DateTime(effectiveDate.year, 1, 1)).inDays;

      if (quotesList.isNotEmpty) {
        final quoteIndex = dayOfYear % quotesList.length;
        final quoteData = quotesList[quoteIndex] as Map<String, dynamic>;
        _dailyQuote = quoteData['quote'] as String? ?? '';
        _dailyQuoteAuthor = quoteData['author'] as String? ?? '';
      }

      // 直近3件の記録からアドバイスを生成
      final recentRecords = await DatabaseHelper.instance.getLatestRecords(limit: 3);
      if (recentRecords.length == 3) {
        final averageScore = recentRecords.map((r) => r.score).reduce((a, b) => a + b) / 3;
        // 3日に1回、またはスコアに特徴があればアドバイス
        if (dayOfYear % 3 == 0 || averageScore <= 4 || averageScore >= 8) {
          if (averageScore <= 4) {
            _dailyQuote = '最近、スコアが低い日が続いていますね。今夜は少し早めに休んでみてはいかがでしょうか？';
            _dailyQuoteAuthor = 'Zzzone';
          } else if (averageScore >= 8) {
            _dailyQuote = '素晴らしい！スコアが高い日が続いています。その調子で良い睡眠を続けましょう！';
            _dailyQuoteAuthor = 'Zzzone';
          }
        }
      }
    } catch (e) {
      _dailyQuote = '今日を素晴らしい一日に。';
      _dailyQuoteAuthor = 'Zzzone';
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _recordDrowsiness() async {
    final latestRecord = await DatabaseHelper.instance.getLatestRecord();
    if (latestRecord == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('まだ睡眠記録がありません')));
      }
      return;
    }

    final newDrowsinessState = !latestRecord.hadDaytimeDrowsiness;
    final updatedRecord = SleepRecord(
      id: latestRecord.id,
      sleepTime: latestRecord.sleepTime,
      wakeUpTime: latestRecord.wakeUpTime,
      score: latestRecord.score,
      performance: latestRecord.performance,
      hadDaytimeDrowsiness: newDrowsinessState,
      hasAchievedGoal: latestRecord.hasAchievedGoal,
      memo: latestRecord.memo,
      didNotOversleep: latestRecord.didNotOversleep,
    );
    await DatabaseHelper.instance.update(updatedRecord);

    if (mounted) {
      final message = newDrowsinessState ? '今日の眠気を記録しました' : '眠気の記録を取り消しました';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _startTimer() {
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepStartTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(_sleepStartTime!);
        });
      }
    });
  }

  void _startSleeping() {
    setState(() {
      _isSleeping = true;
      _sleepStartTime = DateTime.now();
    });
    _startTimer();
  }

  void _stopSleeping() async {
    _timer?.cancel();
    final wakeUpTime = DateTime.now();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostSleepInputScreen(
          sleepTime: _sleepStartTime!,
          wakeUpTime: wakeUpTime,
        ),
      ),
    );
    _updateTopArea(); // 記録保存後に表示を更新
    setState(() {
      _isSleeping = false;
      _sleepStartTime = null;
      _elapsed = Duration.zero;
    });
  }

  void _navigateToHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    _updateTopArea(); // 履歴画面から戻ってきたときも表示を更新
  }

  void _navigateToSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _updateTopArea(); // 設定画面から戻ってきたときも表示を更新
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zzzone'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _navigateToSettings),
          IconButton(icon: const Icon(Icons.history), onPressed: _navigateToHistory),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSleeping)
              Text(
                _formatDuration(_elapsed),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontFamily: 'monospace'),
              ),
            if (!_isSleeping && _dailyQuote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  children: [
                    Text(
                      _dailyQuote,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, height: 1.5, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    if (_dailyQuoteAuthor.isNotEmpty)
                      Text(
                        '- $_dailyQuoteAuthor -',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            _isSleeping
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('起床する'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), textStyle: const TextStyle(fontSize: 20)),
                    onPressed: _stopSleeping,
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.bedtime_outlined),
                    label: const Text('睡眠を開始'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), textStyle: const TextStyle(fontSize: 20)),
                    onPressed: _startSleeping,
                  ),
            if (!_isSleeping)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloudy_snowing),
                  label: const Text('今日の眠気を記録'),
                  onPressed: _recordDrowsiness,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
