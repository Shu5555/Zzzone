import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  Map<String, String> _aiToneOptions = {};

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
    _loadSettings();
  }

  @override
  void dispose() {
    _weatherCityNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
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

    // Load AI Tone Options
    final jsonString = await rootBundle.loadString('assets/persona_display_names.json');
    final Map<String, dynamic> decodedJson = json.decode(jsonString);
    _aiToneOptions = decodedJson.map((key, value) => MapEntry(key, value.toString()));

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
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        String tempPrefecture = _selectedPrefecture;
        final tempCityController = TextEditingController(text: _weatherCityName);
        return AlertDialog(
          title: const Text('天気予報の地点設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: tempPrefecture,
                items: _prefectures.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    // This is a bit of a hack to rebuild the dialog state
                    (context as Element).markNeedsBuild();
                    tempPrefecture = value;
                  }
                },
              ),
              TextField(
                controller: tempCityController,
                decoration: const InputDecoration(labelText: '市区町村名'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'prefecture': tempPrefecture,
                  'city': tempCityController.text,
                });
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('weather_prefecture', result['prefecture']!);
      await prefs.setString('weather_city_name', result['city']!);
      setState(() {
        _selectedPrefecture = result['prefecture']!;
        _weatherCityName = result['city']!;
      });
    }
  }

  void _handleTapGoalTimeSetting() {
    if (_isLocked) {
      final now = DateTime.now();
      final daysRemaining = 7 - now.difference(_weekStartDate!).inDays;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目標時刻の変更は週3回までです。あと$daysRemaining日でリセットされます。')),
      );
    } else {
      _selectTime(context);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _goalTime,
    );
    if (picked != null && picked != _goalTime) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('goalHour', picked.hour);
      await prefs.setInt('goalMinute', picked.minute);
      
      DateTime now = DateTime.now();
      if (_weekStartDate == null) {
        _weekStartDate = now;
        await prefs.setString('goalTimeChangeWeekStart', _weekStartDate!.toIso8601String());
      }
      
      setState(() {
        _goalTime = picked;
        _changeCount++;
      });
      
      await prefs.setInt('goalTimeChangeCount', _changeCount);
      if (_changeCount >= 3) {
        setState(() {
          _isLocked = true;
        });
      }
    }
  }

  Future<void> _deleteAllSleepRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべての睡眠記録を削除'),
        content: const Text('本当にすべての睡眠記録を削除しますか？この操作は元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('sleep_records');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('すべての睡眠記録を削除しました')),
        );
      }
    }
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
