import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/supabase_ranking_service.dart';
import 'about_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabaseService = SupabaseRankingService();

  // Goal Time State
  TimeOfDay _goalTime = const TimeOfDay(hour: 23, minute: 0);
  int _changeCount = 0;
  DateTime? _weekStartDate;
  bool _isLocked = false;

  // Weather settings state
  String _selectedPrefecture = '東京都';
  String _weatherCityName = '千代田区';
  final _weatherCityNameController = TextEditingController();

  // AI Settings State
  String? _userId;
  String _selectedAiTone = 'default';
  String _selectedAiGender = 'unspecified'; // New
  bool _isLoadingAiSettings = true;
  final Map<String, String> _aiToneOptions = {
    'default': '通常',
    'polite': '丁寧',
    'friendly': '友達風',
    'butler': '執事風',
    'tsundere': 'ツンデレ',
    'counselor': 'カウンセラー',
    'childcare': '保育士',
    'researcher': '研究者',
    'android': 'アンドロイド',
    'sage': '賢者',
    'ottori': 'おっとり系',
    'cool': 'クール系',
    'genki': '元気いっぱい',
    'oneesan': 'お姉さん',
    'genius_girl': '天才少女',
    'high_school_boy': '男子高校生',
  };

  static const List<String> _prefectures = [
    '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
    '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
    '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県',
    '静岡県', '愛知県', '三重県', '滋賀県', '京都府', '大阪府', '兵庫県',
    '奈良県', '和歌山県', '鳥取県', '島根県', '岡山県', '広島県', '山口県',
    '徳島県', '香川県', '愛媛県', '高知県', '福岡県', '佐賀県', '長崎県',
    '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県'
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _weatherCityNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    // Load Goal Time
    final hour = prefs.getInt('goalHour') ?? 23;
    final minute = prefs.getInt('goalMinute') ?? 0;
    _goalTime = TimeOfDay(hour: hour, minute: minute);
    _changeCount = prefs.getInt('goalTimeChangeCount') ?? 0;
    final weekStartStr = prefs.getString('goalTimeChangeWeekStart');
    if (weekStartStr != null) {
      _weekStartDate = DateTime.parse(weekStartStr);
      if (DateTime.now().difference(_weekStartDate!).inDays >= 7) {
        _changeCount = 0;
        _weekStartDate = null;
        await prefs.remove('goalTimeChangeCount');
        await prefs.remove('goalTimeChangeWeekStart');
      }
    }
    _isLocked = _changeCount >= 3;

    // Load Weather Location
    _selectedPrefecture = prefs.getString('weather_prefecture') ?? '東京都';
    _weatherCityName = prefs.getString('weather_city_name') ?? '千代田区';

    // Load AI Settings
    if (_userId != null) {
      final userProfile = await _supabaseService.getUser(_userId!);
      if (mounted) {
        _selectedAiTone = userProfile?['ai_tone'] ?? 'default';
        _selectedAiGender = userProfile?['ai_gender_preference'] ?? 'unspecified';
      }
    }

    setState(() {
      _isLoadingAiSettings = false;
    });
  }

  Future<void> _onAiToneChanged(String? newValue) async {
    if (newValue == null || _userId == null) return;

    setState(() {
      _selectedAiTone = newValue;
    });

    try {
      await _supabaseService.updateUserAiTone(userId: _userId!, aiTone: newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AIの口調を変更しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: 口調の変更に失敗しました'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onAiGenderChanged(String? newValue) async {
    if (newValue == null || _userId == null) return;

    setState(() {
      _selectedAiGender = newValue;
    });

    try {
      await _supabaseService.updateUserAiGender(userId: _userId!, aiGender: newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AIに認識される性別を変更しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: 性別の変更に失敗しました'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showWeatherLocationDialog() async {
    // ... (omitted for brevity, unchanged)
  }

  void _handleTapGoalTimeSetting() {
    // ... (omitted for brevity, unchanged)
  }

  Future<void> _selectTime(BuildContext context) async {
    // ... (omitted for brevity, unchanged)
  }

  Future<void> _deleteAllSleepRecords() async {
    // ... (omitted for brevity, unchanged)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('プロフィール設定'),
            subtitle: const Text('ユーザー名やランキングの設定はこちら'),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('目標入眠時刻'),
            subtitle: const Text('設定時刻の前後(-90分～+30分)に入眠するとバッジが記録されます'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _goalTime.format(context),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey),
              ],
            ),
            onTap: _handleTapGoalTimeSetting,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.location_city),
            title: const Text('天気予報の地点'),
            subtitle: Text('$_selectedPrefecture $_weatherCityName'),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: _showWeatherLocationDialog,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('AIアシスタント設定', style: Theme.of(context).textTheme.titleSmall),
          ),
          _buildAiToneSelector(),
          _buildAiGenderSelector(),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('データ管理', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            title: const Text('すべての睡眠記録を削除'),
            subtitle: const Text('アプリ内のすべての睡眠記録を削除します'),
            trailing: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onTap: _deleteAllSleepRecords,
          ),
          const Divider(),
          ListTile(
            title: const Text('アプリ詳細'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiToneSelector() {
    return ListTile(
      leading: const Icon(Icons.psychology_outlined),
      title: const Text('AIの口調設定'),
      trailing: _isLoadingAiSettings
          ? const CircularProgressIndicator()
          : DropdownButton<String>(
              value: _selectedAiTone,
              items: _aiToneOptions.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: _userId == null ? null : _onAiToneChanged,
            ),
    );
  }

  Widget _buildAiGenderSelector() {
    if (_isLoadingAiSettings) return const SizedBox.shrink();
    if (_userId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AIに認識される性別', style: Theme.of(context).textTheme.titleMedium),
          Text('ペルソナによっては応答が少し変化します', style: Theme.of(context).textTheme.bodySmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Radio<String>(
                value: 'unspecified',
                groupValue: _selectedAiGender,
                onChanged: (v) => _onAiGenderChanged(v),
              ),
              const Text('未記入'),
              Radio<String>(
                value: 'male',
                groupValue: _selectedAiGender,
                onChanged: (v) => _onAiGenderChanged(v),
              ),
              const Text('男性'),
              Radio<String>(
                value: 'female',
                groupValue: _selectedAiGender,
                onChanged: (v) => _onAiGenderChanged(v),
              ),
              const Text('女性'),
            ],
          ),
        ],
      ),
    );
  }
}