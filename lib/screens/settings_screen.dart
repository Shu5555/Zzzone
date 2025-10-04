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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
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

    setState(() {});
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

  Future<void> _deleteAllSleepRecords() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべての睡眠記録を削除しますか？'),
        content: const Text('この操作は元に戻せません。アプリ内のすべての睡眠記録が完全に削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('削除する'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteAllRecords();

        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId');
        if (userId != null) {
          final supabaseService = SupabaseRankingService();
          await supabaseService.deleteUser(userId); // This will also delete sleep records on server due to CASCADE
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('すべての睡眠記録を削除しました。')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: 睡眠記録の削除に失敗しました。\n${e.toString()}')),
          );
        }
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