import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/date_helper.dart'; // New import

import '../gacha/models/gacha_item.dart';
import '../gacha/services/gacha_data_loader.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import '../services/supabase_ranking_service.dart';
import 'history_screen.dart';
import 'quote_list_screen.dart';
import 'ranking_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'sleep_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Services
  final _supabaseService = SupabaseRankingService();

  // State
  static const String _sleepStartTimeKey = 'sleep_start_time';
  bool _isSleeping = false;
  DateTime? _sleepStartTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String _dailyQuote = '';
  String _dailyQuoteAuthor = '';
  SleepRecord? _todayRecord;
  bool _isDrowsinessRecordable = false;

  // Gacha related state
  List<GachaItem> _allGachaItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadSleepSession();
    await _updateTopArea(); // This will now load the favorite quote
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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        _dailyQuote = 'プロフィールからランキングに参加して、ガチャを引いてみよう！';
        _dailyQuoteAuthor = 'Zzzone';
        if (mounted) setState(() {});
        return;
      }

      // Load all possible gacha items and user profile simultaneously
      final results = await Future.wait([
        GachaDataLoader.loadItems('assets/gacha/gacha_items.json'),
        _supabaseService.getUser(userId),
      ]);

      _allGachaItems = results[0] as List<GachaItem>;
      final userProfile = results[1] as Map<String, dynamic>?;
      final favoriteQuoteId = userProfile?['favorite_quote_id'] as String?;

      if (favoriteQuoteId == 'random') {
        // Random Mode: Display a deterministic random quote of the day
        final unlockedQuoteIds = await DatabaseHelper.instance.getUnlockedQuoteIds();
        if (unlockedQuoteIds.isNotEmpty) {
          final now = DateTime.now();
          final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
          final quoteIdToShow = unlockedQuoteIds[dayOfYear % unlockedQuoteIds.length];
          
          final quote = _allGachaItems.firstWhere((item) => item.id == quoteIdToShow, orElse: () => GachaItem(id: 'not_found', rarityId: 'common'));
          if (quote.id != 'not_found') {
            _dailyQuote = quote.text ?? '';
            _dailyQuoteAuthor = quote.author ?? '';
          } else {
            _dailyQuote = 'エラー: 名言が見つかりません。';
            _dailyQuoteAuthor = 'Zzzone';
          }
        } else {
          _dailyQuote = 'ガチャで名言を獲得して、日替わり表示を楽しもう！';
          _dailyQuoteAuthor = 'Zzzone';
        }
      } else if (favoriteQuoteId != null) {
        // Favorite Mode: Display the selected favorite quote
        final quote = _allGachaItems.firstWhere((item) => item.id == favoriteQuoteId, orElse: () => GachaItem(id: 'not_found', rarityId: 'common'));
        if (quote.id != 'not_found') {
          _dailyQuote = quote.text ?? '';
          _dailyQuoteAuthor = quote.author ?? '';
          
          
        } else {
          _dailyQuote = 'お気に入りの名言が見つかりません。設定し直してください。';
          _dailyQuoteAuthor = 'Zzzone';
        }
      } else {
        // No Favorite or Random mode set
        _dailyQuote = '名言一覧からお気に入りを設定できます';
        _dailyQuoteAuthor = 'Zzzone';
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
        builder: (context) => SleepEditScreen(
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

  void _navigateTo(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    _loadData(); // Refresh data when returning to home screen
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
    final bool isTodaySaturday = isSaturday(DateTime.now()); // Check if today is Saturday

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zzzone'),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_quote_outlined),
            tooltip: '名言一覧',
            onPressed: () => _navigateTo(const QuoteListScreen()),
          ),
          // New Gacha Shortcut Button
          IconButton(
            icon: const Icon(Icons.card_giftcard_outlined),
            tooltip: 'ガチャ',
            onPressed: () => _navigateTo(const ShopScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'ランキング',
            onPressed: () => _navigateTo(const RankingScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () => _navigateTo(const SettingsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: '履歴',
            onPressed: () => _navigateTo(const HistoryScreen()),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isTodaySaturday) // Conditionally display "S"
              const Text(
                'S',
                style: TextStyle(
                  fontSize: 80, // Large size
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow, // Yellow color
                ),
              ),
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