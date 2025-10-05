import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import 'sleep_edit_screen.dart'; // Updated import
import 'history_screen.dart';
import 'settings_screen.dart';
import 'ranking_screen.dart';
import 'shop_screen.dart'; // Import the shop screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _sleepStartTimeKey = 'sleep_start_time';

  bool _isSleeping = false;
  DateTime? _sleepStartTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String _dailyQuote = '';
  String _dailyQuoteAuthor = '';

  SleepRecord? _todayRecord;
  bool _isDrowsinessRecordable = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadSleepSession();
    await _updateTopArea();
    final record = await DatabaseHelper.instance.getRecordForDate(DateTime.now());
    if (mounted) {
      setState(() {
        _todayRecord = record;
        _isDrowsinessRecordable = record != null && !record.hadDaytimeDrowsiness;
      });
    }
  }

  Future<void> _loadSleepSession() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeString = prefs.getString(_sleepStartTimeKey);
    if (startTimeString != null) {
      if (mounted) {
        setState(() {
          _sleepStartTime = DateTime.parse(startTimeString);
          _isSleeping = true;
        });
      }
      _startTimer();
    }
  }

  Future<void> _updateTopArea() async {
    try {
      // 1. Load the default quote (Kant, etc.)
      final String jsonString = await rootBundle.loadString('assets/data/quotes.json');
      final List<dynamic> quotesList = jsonDecode(jsonString);
      final now = DateTime.now();
      final effectiveDate = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
      final dayOfYear = effectiveDate.difference(DateTime(effectiveDate.year, 1, 1)).inDays;

      if (quotesList.isNotEmpty) {
        final quoteIndex = dayOfYear % quotesList.length;
        final quoteData = quotesList[quoteIndex] as Map<String, dynamic>;
        _dailyQuote = quoteData['quote'] as String? ?? '';
        _dailyQuoteAuthor = quoteData['author'] as String? ?? '';
      } else {
        // Fallback if quotes.json is empty
        _dailyQuote = '今日を素晴らしい一日に。';
        _dailyQuoteAuthor = 'Zzzone';
      }

      // 2. Check for conditions to show a special Zzzone comment
      final prefs = await SharedPreferences.getInstance();
      final dateString = '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}';
      final zzzoneCommentShownKey = 'zzzone_comment_shown_$dateString';
      final hasShownZzzoneComment = prefs.getBool(zzzoneCommentShownKey) ?? false;

      final recentRecords = await DatabaseHelper.instance.getLatestRecords(limit: 3);
      if (recentRecords.length == 3 && !hasShownZzzoneComment) {
        final averageScore = recentRecords.map((r) => r.score).reduce((a, b) => a + b) / 3;
        
        String? zzzoneQuote;
        if (averageScore <= 4) {
          zzzoneQuote = '最近、スコアが低い日が続いていますね。今夜は少し早めに休んでみてはいかがでしょうか？';
        } else if (averageScore >= 8) {
          zzzoneQuote = '素晴らしい！スコアが高い日が続いています。その調子で良い睡眠を続けましょう！';
        }

        if (zzzoneQuote != null) {
          _dailyQuote = zzzoneQuote;
          _dailyQuoteAuthor = 'Zzzone';
          // Mark as shown for today
          await prefs.setBool(zzzoneCommentShownKey, true);
        }
      }
    } catch (e) {
      // In case of any error, show a generic fallback
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
    if (_todayRecord == null) return;

    final updatedRecord = _todayRecord!.copyWith(hadDaytimeDrowsiness: true);
    await DatabaseHelper.instance.update(updatedRecord);

    if (mounted) {
      setState(() {
        _todayRecord = updatedRecord;
        _isDrowsinessRecordable = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昼間の眠気を記録しました。')),
      );
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

  void _startSleeping() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSleeping = true;
      _sleepStartTime = DateTime.now();
    });
    await prefs.setString(_sleepStartTimeKey, _sleepStartTime!.toIso8601String());
    _startTimer();
  }

  void _stopSleeping() async {
    final prefs = await SharedPreferences.getInstance();
    _timer?.cancel();
    final wakeUpTime = DateTime.now();
    await prefs.remove(_sleepStartTimeKey);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SleepEditScreen( // Navigate to the new screen
          initialSleepTime: _sleepStartTime!,
          initialWakeUpTime: wakeUpTime,
        ),
      ),
    );
    _loadData();
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
    _loadData();
  }

  void _navigateToSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _loadData();
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
          IconButton(
            icon: const Icon(Icons.store_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RankingScreen())),
          ),
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
            if (!_isSleeping && _todayRecord != null)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ElevatedButton(
                  onPressed: _isDrowsinessRecordable ? _recordDrowsiness : null,
                  child: Text(
                    _isDrowsinessRecordable ? '昼間の眠気を記録' : '眠気は記録済み',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
