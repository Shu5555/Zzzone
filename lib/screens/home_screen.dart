import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/date_helper.dart'; // New import

import '../gacha/models/gacha_item.dart';
import '../gacha/services/gacha_data_loader.dart';
import '../models/sleep_record.dart';
import '../models/weather.dart';
import '../models/weather_info.dart';
import '../services/database_helper.dart';
import '../services/supabase_ranking_service.dart';
import '../services/weather_service.dart';
import 'history_screen.dart';
import 'quote_list_screen.dart';
import 'ranking_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'sleep_edit_screen.dart';
import 'announcements_screen.dart';

import '../services/announcement_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Services
  final _supabaseService = SupabaseRankingService();
  final _announcementService = AnnouncementService();
  final _weatherService = WeatherService();

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
  bool _hasUnreadAnnouncements = false;

  // Gacha related state
  List<GachaItem> _allGachaItems = [];

  // Weather state
  WeatherInfo? _weatherInfo;
  bool _isLoadingWeather = true;
  String? _weatherError;

  static const Map<String, String> _prefectureCapitals = {
    '北海道': '札幌市', '青森県': '青森市', '岩手県': '盛岡市', '宮城県': '仙台市', '秋田県': '秋田市', 
    '山形県': '山形市', '福島県': '福島市', '茨城県': '水戸市', '栃木県': '宇都宮市', '群馬県': '前橋市', 
    '埼玉県': 'さいたま市', '千葉県': '千葉市', '東京都': '新宿区', '神奈川県': '横浜市', '新潟県': '新潟市', 
    '富山県': '富山市', '石川県': '金沢市', '福井県': '福井市', '山梨県': '甲府市', '長野県': '長野市', 
    '岐阜県': '岐阜市', '静岡県': '静岡市', '愛知県': '名古屋市', '三重県': '津市', '滋賀県': '大津市', 
    '京都府': '京都市', '大阪府': '大阪市', '兵庫県': '神戸市', '奈良県': '奈良市', '和歌山県': '和歌山市', 
    '鳥取県': '鳥取市', '島根県': '松江市', '岡山県': '岡山市', '広島県': '広島市', '山口県': '山口市', 
    '徳島県': '徳島市', '香川県': '高松市', '愛媛県': '松山市', '高知県': '高知市', '福岡県': '福岡市', 
    '佐賀県': '佐賀市', '長崎県': '長崎市', '熊本県': '熊本市', '大分県': '大分市', '宮崎県': '宮崎市', 
    '鹿児島県': '鹿児島市', '沖縄県': '那覇市'
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkUnreadStatus();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefecture = prefs.getString('weather_prefecture') ?? '東京都';
      final city = prefs.getString('weather_city_name') ?? '';

      String query;
      if (city.isEmpty) {
        // If city is empty, use the prefecture's capital city
        query = _prefectureCapitals[prefecture] ?? prefecture;
      } else {
        query = '$city,$prefecture';
      }

      final weatherInfo = await _weatherService.getWeather(query);
      if (mounted) {
        setState(() {
          _weatherInfo = weatherInfo;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = e.toString().replaceAll('Exception: ', '');
          _isLoadingWeather = false;
        });
      }
    }
  }

  Future<void> _checkUnreadStatus() async {
    final hasUnread = await _announcementService.hasUnreadAnnouncements();
    if (mounted) {
      setState(() {
        _hasUnreadAnnouncements = hasUnread;
      });
    }
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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        _dailyQuote = 'プロフィールからランキングに参加して、ガチャを引いてみよう！';
        _dailyQuoteAuthor = 'Zzzone';
        if (mounted) setState(() {});
        return;
      }

      final results = await Future.wait([
        GachaDataLoader.loadItems('assets/gacha/gacha_items.json'),
        _supabaseService.getUser(userId),
      ]);

      _allGachaItems = results[0] as List<GachaItem>;
      final userProfile = results[1] as Map<String, dynamic>?;
      final favoriteQuoteId = userProfile?['favorite_quote_id'] as String?;

      if (favoriteQuoteId == 'random') {
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
        final quote = _allGachaItems.firstWhere((item) => item.id == favoriteQuoteId, orElse: () => GachaItem(id: 'not_found', rarityId: 'common'));
        if (quote.id != 'not_found') {
          _dailyQuote = quote.text ?? '';
          _dailyQuoteAuthor = quote.author ?? '';
        } else {
          _dailyQuote = 'お気に入りの名言が見つかりません。設定し直してください。';
          _dailyQuoteAuthor = 'Zzzone';
        }
      } else {
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

  void _navigateTo(Widget screen, {bool isSettings = false, bool isAnnouncements = false}) async {

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    _loadData();

    if (isSettings) {
      _fetchWeather(); // Re-fetch weather after returning from settings
    }

    if (!isAnnouncements) {
      _checkUnreadStatus();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Widget _buildWeatherWidget() {
    if (_isLoadingWeather) {
      return const SizedBox(height: 50); // Reserve space while loading
    }

    if (_weatherError != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          '天気情報の取得エラー: $_weatherError',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_weatherInfo == null) {
      return const SizedBox.shrink();
    }

    final locationName = '${_weatherInfo!.prefectureName} ${_weatherInfo!.cityName}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.network(
          'https://openweathermap.org/img/wn/${_weatherInfo!.weather.iconCode}@2x.png',
          width: 50,
          height: 50,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$locationNameの天気: ${_weatherInfo!.weather.description}'),
            Text('気温: ${_weatherInfo!.weather.temperature.toStringAsFixed(1)} °C'),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTodaySaturday = isSaturday(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zzzone'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'お知らせ',
                onPressed: () {
                  _navigateTo(AnnouncementsScreen(), isAnnouncements: true);
                },
              ),
              if (_hasUnreadAnnouncements)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.format_quote_outlined),
            tooltip: '名言一覧',
            onPressed: () {
              _navigateTo(QuoteListScreen());
            },
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard_outlined),
            tooltip: 'ガチャ',
            onPressed: () {
              _navigateTo(ShopScreen());
            },
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'ランキング',
            onPressed: () {
              _navigateTo(RankingScreen());
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () {
              _navigateTo(SettingsScreen(), isSettings: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: '履歴',
            onPressed: () {
              _navigateTo(HistoryScreen());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isTodaySaturday)
                        const Text(
                          'S',
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.yellow,
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
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: _buildWeatherWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}