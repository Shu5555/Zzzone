import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Goal Time State
  TimeOfDay _goalTime = const TimeOfDay(hour: 23, minute: 0);
  int _changeCount = 0;
  DateTime? _weekStartDate;
  bool _isLocked = false;

  // Ranking State
  final ApiService _apiService = ApiService();
  final TextEditingController _userNameController = TextEditingController();
  bool _rankingParticipation = false;
  String? _userId;
  String _initialUserName = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _updateSettingsOnExit();
    _userNameController.dispose();
    super.dispose();
  }

  Future<void> _updateSettingsOnExit() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUsername = _userNameController.text;

    // Save username locally
    await prefs.setString('userName', currentUsername);

    // Sync username with server if it has changed and user is participating
    if (_rankingParticipation && _userId != null && currentUsername != _initialUserName) {
      await _apiService.updateUser(_userId!, currentUsername);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

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

    // Load Ranking Settings
    _initialUserName = prefs.getString('userName') ?? '';
    _userNameController.text = _initialUserName;
    _rankingParticipation = prefs.getBool('rankingParticipation') ?? false;
    _userId = prefs.getString('userId');

    setState(() {});
  }

  Future<void> _saveRankingParticipation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rankingParticipation', value);
    setState(() {
      _rankingParticipation = value;
    });

    // First time opting in
    if (value && _userId == null) {
      final newUserId = const Uuid().v4();
      await prefs.setString('userId', newUserId);
      setState(() {
        _userId = newUserId;
      });
      // Register user on the server
      await _apiService.updateUser(newUserId, _userNameController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ランキング用のIDを生成し、ユーザー情報を登録しました')),
        );
      }
    } else if (value && _userId != null) {
      // Re-opting in, just sync the current state
      await _apiService.updateUser(_userId!, _userNameController.text);
    }
  }

  void _handleTapGoalTimeSetting() {
    if (_isLocked && _weekStartDate != null) {
      final nextChangeableDate = _weekStartDate!.add(const Duration(days: 7));
      final formattedDate = DateFormat('M/d').format(nextChangeableDate);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('変更回数の上限'),
          content: Text('今週の変更回数の上限に達しました。\n次回は $formattedDate 以降に変更できます。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    } else {
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('目標時刻の変更'),
          content: Text('今週の残り変更回数は ${3 - _changeCount} 回です。\n変更しますか？'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('変更する')),
          ],
        ),
      ).then((confirmed) {
        if (confirmed == true) {
          _selectTime(context);
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _goalTime,
    );
    if (picked != null && picked != _goalTime) {
      final prefs = await SharedPreferences.getInstance();
      DateTime now = DateTime.now();

      if (_weekStartDate == null) {
        _weekStartDate = now;
        await prefs.setString('goalTimeChangeWeekStart', _weekStartDate!.toIso8601String());
      }

      _changeCount++;
      await prefs.setInt('goalTimeChangeCount', _changeCount);
      await prefs.setInt('goalHour', picked.hour);
      await prefs.setInt('goalMinute', picked.minute);

      setState(() {
        _goalTime = picked;
        _isLocked = _changeCount >= 3;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目標時刻を変更しました')),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('ランキング設定', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            title: const Text('ユーザー名'),
            subtitle: TextField(
              controller: _userNameController,
              decoration: const InputDecoration(
                hintText: 'ランキングに表示される名前',
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('ランキングに参加する'),
            subtitle: const Text('睡眠時間をサーバーに送信し、全国ランキングに参加します'),
            value: _rankingParticipation,
            onChanged: _saveRankingParticipation,
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
