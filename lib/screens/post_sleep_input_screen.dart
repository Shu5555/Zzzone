import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import '../utils/date_helper.dart';
import '../services/api_service.dart';

class PostSleepInputScreen extends StatefulWidget {
  final DateTime? sleepTime;
  final DateTime? wakeUpTime;
  final SleepRecord? initialRecord;

  const PostSleepInputScreen({
    super.key,
    this.sleepTime,
    this.wakeUpTime,
    this.initialRecord,
  }) : assert(initialRecord != null || (sleepTime != null && wakeUpTime != null));

  @override
  State<PostSleepInputScreen> createState() => _PostSleepInputScreenState();
}

class _PostSleepInputScreenState extends State<PostSleepInputScreen> {
  late double _score;
  late int _performance;
  late bool _didNotOversleep;
  late final TextEditingController _memoController;
  bool _isSaving = false; // 保存状態を管理するフラグ

  bool get isEditing => widget.initialRecord != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _score = widget.initialRecord!.score.toDouble();
      _performance = widget.initialRecord!.performance;
      _didNotOversleep = widget.initialRecord!.didNotOversleep;
      _memoController = TextEditingController(text: widget.initialRecord!.memo);
    } else {
      _score = 5.0;
      _performance = 2;
      _didNotOversleep = false;
      _memoController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    if (_isSaving) return; // 保存中なら何もしない
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final goalHour = prefs.getInt('goalHour') ?? 23;
      final goalMinute = prefs.getInt('goalMinute') ?? 0;

      final sleepTime = isEditing ? widget.initialRecord!.sleepTime : widget.sleepTime!;
      final wakeUpTime = isEditing ? widget.initialRecord!.wakeUpTime : widget.wakeUpTime!;

      final logicalSleepDate = getLogicalDate(sleepTime);
      var targetDateTime = DateTime(logicalSleepDate.year, logicalSleepDate.month, logicalSleepDate.day, goalHour, goalMinute);

      if (goalHour < 4) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }

      final startTime = targetDateTime.subtract(const Duration(minutes: 90));
      final endTime = targetDateTime.add(const Duration(minutes: 30));
      final bool achieved = !sleepTime.isBefore(startTime) && !sleepTime.isAfter(endTime);

      SleepRecord recordToSave;
      if (isEditing) {
        recordToSave = SleepRecord(
          id: widget.initialRecord!.id,
          sleepTime: widget.initialRecord!.sleepTime,
          wakeUpTime: widget.initialRecord!.wakeUpTime,
          score: _score.round(),
          performance: _performance,
          hadDaytimeDrowsiness: widget.initialRecord!.hadDaytimeDrowsiness,
          hasAchievedGoal: achieved,
          memo: _memoController.text,
          didNotOversleep: _didNotOversleep,
        );
        await DatabaseHelper.instance.update(recordToSave);
      } else {
        recordToSave = SleepRecord(
          sleepTime: widget.sleepTime!,
          wakeUpTime: widget.wakeUpTime!,
          score: _score.round(),
          performance: _performance,
          hadDaytimeDrowsiness: false,
          hasAchievedGoal: achieved,
          memo: _memoController.text,
          didNotOversleep: _didNotOversleep,
        );
        recordToSave = await DatabaseHelper.instance.create(recordToSave);
      }



      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録を保存しました')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      // エラーが発生した場合でもフラグをリセット
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

  Future<void> _deleteRecord() async {
    if (!isEditing) return;

    final bool? confirmed = await showDialog<bool>(
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
      await DatabaseHelper.instance.delete(widget.initialRecord!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録を削除しました')));
        int count = 0;
        Navigator.of(context).popUntil((_) => count++ >= 2);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '記録の編集' : '睡眠の評価'),
        actions: [
          if (isEditing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteRecord),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                onPressed: _isSaving ? null : _saveRecord,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('記録を保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
