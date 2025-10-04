import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import '../utils/date_helper.dart';
import '../services/supabase_ranking_service.dart';

enum EditMode { auto, manual, edit }

class SleepEditScreen extends StatefulWidget {
  final DateTime? initialSleepTime;
  final DateTime? initialWakeUpTime;
  final SleepRecord? existingRecord;

  const SleepEditScreen({
    super.key,
    this.initialSleepTime,
    this.initialWakeUpTime,
    this.existingRecord,
  });

  @override
  State<SleepEditScreen> createState() => _SleepEditScreenState();
}

class _SleepEditScreenState extends State<SleepEditScreen> {
  late EditMode _mode;
  final _supabaseService = SupabaseRankingService();

  // Form state
  late DateTime _recordDate, _sleepTime, _wakeUpTime;
  late double _score;
  late int _performance;
  late bool _didNotOversleep;
  late bool _hadDaytimeDrowsiness;
  final _memoController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _determineModeAndInitializeState();
  }

  void _determineModeAndInitializeState() {
    if (widget.existingRecord != null) {
      _mode = EditMode.edit;
      final record = widget.existingRecord!;
      _recordDate = record.recordDate;
      _sleepTime = record.sleepTime;
      _wakeUpTime = record.wakeUpTime;
      _score = record.score.toDouble();
      _performance = record.performance;
      _didNotOversleep = record.didNotOversleep;
      _hadDaytimeDrowsiness = record.hadDaytimeDrowsiness;
      _memoController.text = record.memo ?? '';
    } else if (widget.initialSleepTime != null && widget.initialWakeUpTime != null) {
      _mode = EditMode.auto;
      _sleepTime = widget.initialSleepTime!;
      _wakeUpTime = widget.initialWakeUpTime!;
      _recordDate = getLogicalDate(_wakeUpTime); // 起床時間に基づいて記録日を決定
      // Default values for new record
      _score = 5.0;
      _performance = 2;
      _didNotOversleep = false;
      _hadDaytimeDrowsiness = false;
    } else {
      _mode = EditMode.manual;
      final now = DateTime.now();
      _recordDate = getLogicalDate(now);
      _sleepTime = DateTime(now.year, now.month, now.day, 23, 0); // Default to 23:00
      _wakeUpTime = _sleepTime.add(const Duration(hours: 8)); // Default to 8 hours sleep
      // Default values for new record
      _score = 5.0;
      _performance = 2;
      _didNotOversleep = false;
      _hadDaytimeDrowsiness = false;
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  String get _appBarTitle {
    switch (_mode) {
      case EditMode.edit:
        return '記録の編集';
      case EditMode.auto:
        return '睡眠の評価';
      case EditMode.manual:
        return '手動で記録';
    }
  }

  Future<void> _saveRecord() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // --- Validation ---
      if (_wakeUpTime.isBefore(_sleepTime)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('起床時刻は就寝時刻より後にしてください。')));
        setState(() => _isSaving = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final goalHour = prefs.getInt('goalHour') ?? 23;
      final goalMinute = prefs.getInt('goalMinute') ?? 0;
      final logicalSleepDate = getLogicalDate(_sleepTime);
      var targetDateTime = DateTime(logicalSleepDate.year, logicalSleepDate.month, logicalSleepDate.day, goalHour, goalMinute);
      if (goalHour < 4) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }
      final startTime = targetDateTime.subtract(const Duration(minutes: 90));
      final endTime = targetDateTime.add(const Duration(minutes: 30));
      final hasAchievedGoal = !_sleepTime.isBefore(startTime) && !_sleepTime.isAfter(endTime);

      late SleepRecord recordToSave;

      if (_mode == EditMode.edit) {
        recordToSave = widget.existingRecord!.copyWith(
          sleepTime: _sleepTime,
          wakeUpTime: _wakeUpTime,
          score: _score.round(),
          performance: _performance,
          hadDaytimeDrowsiness: _hadDaytimeDrowsiness,
          didNotOversleep: _didNotOversleep,
          memo: _memoController.text,
          hasAchievedGoal: hasAchievedGoal,
        );
        await DatabaseHelper.instance.update(recordToSave);
      } else {
        recordToSave = SleepRecord(
          dataId: const Uuid().v4(),
          recordDate: _recordDate,
          sleepTime: _sleepTime,
          wakeUpTime: _wakeUpTime,
          score: _score.round(),
          performance: _performance,
          hadDaytimeDrowsiness: _hadDaytimeDrowsiness,
          didNotOversleep: _didNotOversleep,
          memo: _memoController.text,
          hasAchievedGoal: hasAchievedGoal,
        );
        await DatabaseHelper.instance.create(recordToSave);
      }

      final isRankingEnabled = prefs.getBool('isRankingEnabled') ?? false;
      final userId = prefs.getString('userId');
      final today = getLogicalDate(DateTime.now());

      if (isRankingEnabled && userId != null && recordToSave.recordDate == today) {
        // Ensure user exists on the server before submitting a record
        final username = prefs.getString('userName') ?? '';
        await _supabaseService.updateUser(id: userId, username: username);

        await _supabaseService.submitRecord(
          userId: userId,
          dataId: recordToSave.dataId,
          sleepDuration: recordToSave.duration.inMinutes,
          date: DateFormat('yyyy-MM-dd').format(recordToSave.recordDate),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録を保存しました')));
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteRecord() async {
    if (_mode != EditMode.edit) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('この記録を本当に削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.delete(widget.existingRecord!.dataId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録を削除しました')));
      int count = 0;
      Navigator.of(context).popUntil((_) => count++ >= 2); // Pop twice to go back to history
    }
  }

  Future<void> _selectRecordDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _recordDate) {
      setState(() {
        _recordDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isSleepTime) async {
    final initialTime = isSleepTime ? TimeOfDay.fromDateTime(_sleepTime) : TimeOfDay.fromDateTime(_wakeUpTime);
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      setState(() {
        if (isSleepTime) {
          _sleepTime = DateTime(_sleepTime.year, _sleepTime.month, _sleepTime.day, picked.hour, picked.minute);
        } else {
          _wakeUpTime = DateTime(_wakeUpTime.year, _wakeUpTime.month, _wakeUpTime.day, picked.hour, picked.minute);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManualOrEdit = _mode == EditMode.manual || _mode == EditMode.edit;
    final duration = _wakeUpTime.difference(_sleepTime);

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          if (_mode == EditMode.edit)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteRecord, tooltip: '削除'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('記録日'),
              trailing: Text(DateFormat('yyyy/MM/dd').format(_recordDate), style: Theme.of(context).textTheme.titleMedium),
              onTap: _mode == EditMode.manual ? () => _selectRecordDate(context) : null,
              enabled: _mode == EditMode.manual,
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('就寝'),
                    trailing: Text(DateFormat('HH:mm').format(_sleepTime), style: Theme.of(context).textTheme.titleMedium),
                    onTap: isManualOrEdit ? () => _selectTime(context, true) : null,
                    enabled: isManualOrEdit,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('起床'),
                    trailing: Text(DateFormat('HH:mm').format(_wakeUpTime), style: Theme.of(context).textTheme.titleMedium),
                    onTap: isManualOrEdit ? () => _selectTime(context, false) : null,
                    enabled: isManualOrEdit,
                  ),
                ),
              ],
            ),
            Center(
              child: Text(
                '睡眠時間: ${duration.inHours}時間 ${duration.inMinutes.remainder(60)}分',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 32),
            Text('睡眠スコア (1-10)', style: Theme.of(context).textTheme.titleLarge),
            Slider(
              value: _score,
              min: 1,
              max: 10,
              divisions: 9,
              label: _score.round().toString(),
              onChanged: (value) => setState(() => _score = value),
            ),
            const SizedBox(height: 24),

            // --- Added UI Components ---
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
            CheckboxListTile(
              title: const Text('昼間に眠気がありました'),
              subtitle: const Text('正直に記録しましょう'),
              value: _hadDaytimeDrowsiness,
              onChanged: (bool? value) {
                setState(() {
                  _hadDaytimeDrowsiness = value ?? false;
                });
              },
            ),
            const SizedBox(height: 24),
            // --- End of Added UI Components ---

            Text('メモ', style: Theme.of(context).textTheme.titleLarge),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '夢の内容や、睡眠の感想など'),
              maxLines: 3,
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRecord,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
                child: _isSaving
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
