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
  TimeOfDay _goalTime = const TimeOfDay(hour: 23, minute: 0);
  int _changeCount = 0;
  DateTime? _weekStartDate;
  bool _isLocked = false;

  // Weather settings state
  String _selectedPrefecture = '東京都';
  String _weatherCityName = '千代田区';
  final _weatherCityNameController = TextEditingController();

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

    // Load weather location
    _selectedPrefecture = prefs.getString('weather_prefecture') ?? '東京都';
    _weatherCityName = prefs.getString('weather_city_name') ?? '千代田区';

    setState(() {});
  }

  Future<void> _showWeatherLocationDialog() async {
    _weatherCityNameController.text = _weatherCityName;
    String dialogPrefecture = _selectedPrefecture;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('天気予報の地点を設定'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: dialogPrefecture,
                      items: _prefectures.map((String prefecture) {
                        return DropdownMenuItem<String>(
                          value: prefecture,
                          child: Text(prefecture),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            dialogPrefecture = newValue;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: '都道府県'),
                    ),
                    TextField(
                      controller: _weatherCityNameController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: '市区町村', hintText: '例: 千代田区'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final newPrefecture = dialogPrefecture;
      final newCityName = _weatherCityNameController.text;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('weather_prefecture', newPrefecture);
      await prefs.setString('weather_city_name', newCityName);
      setState(() {
        _selectedPrefecture = newPrefecture;
        _weatherCityName = newCityName;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地点を設定しました')),
        );
      }
    }
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
}