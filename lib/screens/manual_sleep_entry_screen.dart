import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../utils/date_helper.dart';

class ManualSleepEntryScreen extends StatefulWidget {
  const ManualSleepEntryScreen({super.key});

  @override
  State<ManualSleepEntryScreen> createState() => _ManualSleepEntryScreenState();
}

class _ManualSleepEntryScreenState extends State<ManualSleepEntryScreen> {
  DateTime _selectedDate = DateTime.now();
  int _selectedHours = 7;
  int _selectedMinutes = 30;

  // ▼▼▼ 評価項目用のState変数を追加 ▼▼▼
  double _score = 5.0;
  int _performance = 2;
  bool _didNotOversleep = false;
  late final TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveRecord() async {
    final totalMinutes = _selectedHours * 60 + _selectedMinutes;
    if (totalMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('睡眠時間は0より大きくしてください。')),
      );
      return;
    }

    final sleepTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0);
    final wakeUpTime = sleepTime.add(Duration(minutes: totalMinutes));

    // ▼▼▼ 入力値を使ってSleepRecordを生成 ▼▼▼
    final newRecord = SleepRecord(
      sleepTime: sleepTime,
      wakeUpTime: wakeUpTime,
      score: _score.round(),
      performance: _performance,
      hadDaytimeDrowsiness: false, // この項目は手動入力画面にないためデフォルト値
      hasAchievedGoal: false, // 目標達成は自動計算されないためデフォルト値
      memo: _memoController.text,
      didNotOversleep: _didNotOversleep,
    );

    await DatabaseHelper.instance.create(newRecord);

    final logicalTodayString = getLogicalDateString(DateTime.now());
    final selectedDateString = getLogicalDateString(_selectedDate);

    if (logicalTodayString == selectedDateString) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId != null && userId.isNotEmpty) {
        ApiService().submitRecord(userId, totalMinutes, selectedDateString);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録を保存しました')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手動で記録を追加'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('日付', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              title: Text(DateFormat('yyyy年M月d日').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 24),

            Text('睡眠時間', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimePicker((val) => setState(() => _selectedHours = val), _selectedHours, 24, '時間'),
                const Text(' : ', style: TextStyle(fontSize: 24)),
                _buildTimePicker((val) => setState(() => _selectedMinutes = val), _selectedMinutes, 60, '分', 5),
              ],
            ),
            const Divider(height: 48),

            // ▼▼▼ 評価項目のUIを追加 ▼▼▼
            Text('睡眠スコア (1-10)', style: Theme.of(context).textTheme.titleLarge),
            Slider(
              value: _score,
              min: 1,
              max: 10,
              divisions: 9,
              label: _score.round().toString(),
              onChanged: (value) {
                setState(() {
                  _score = value;
                });
              },
            ),
            const SizedBox(height: 24),

            Text('日中の体感パフォーマンス', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('悪い')),
                ButtonSegment(value: 2, label: Text('普通')),
                ButtonSegment(value: 3, label: Text('良い')),
              ],
              selected: {_performance},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _performance = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),

            CheckboxListTile(
              title: const Text('二度寝しませんでした'),
              subtitle: const Text('素晴らしい一日を始めましょう！'),
              value: _didNotOversleep,
              onChanged: (bool? value) {
                setState(() {
                  _didNotOversleep = value ?? false;
                });
              },
            ),
            const SizedBox(height: 24),

            Text('メモ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '夢の内容や、睡眠の感想など',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 40),

            Center(
              child: ElevatedButton(
                onPressed: _saveRecord,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
                child: const Text('この内容で保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(ValueChanged<int> onChanged, int value, int max, String unit, [int step = 1]) {
    return Row(
      children: [
        DropdownButton<int>(
          value: value,
          onChanged: (int? newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
          items: List.generate(max, (index) => index * step)
              .where((v) => v < max)
              .map<DropdownMenuItem<int>>((int val) {
            return DropdownMenuItem<int>(
              value: val,
              child: Text(val.toString().padLeft(2, '0')),
            );
          }).toList(),
        ),
        const SizedBox(width: 8),
        Text(unit),
      ],
    );
  }
}
