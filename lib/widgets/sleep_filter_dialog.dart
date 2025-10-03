import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sleep_filter_criteria.dart';

class SleepFilterDialog extends StatefulWidget {
  final SleepFilterCriteria initialCriteria;

  const SleepFilterDialog({super.key, required this.initialCriteria});

  @override
  State<SleepFilterDialog> createState() => _SleepFilterDialogState();
}

class _SleepFilterDialogState extends State<SleepFilterDialog> {
  late SleepFilterCriteria _currentCriteria;

  @override
  void initState() {
    super.initState();
    _currentCriteria = widget.initialCriteria;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('睡眠記録を絞り込む'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 睡眠時間
            Text('睡眠時間 (時間)', style: Theme.of(context).textTheme.titleMedium),
            RangeSlider(
              values: RangeValues(
                (_currentCriteria.minSleepDurationHours ?? 0).toDouble(),
                (_currentCriteria.maxSleepDurationHours ?? 24).toDouble(),
              ),
              min: 0,
              max: 24,
              divisions: 24,
              labels: RangeLabels(
                (_currentCriteria.minSleepDurationHours ?? 0).toString(),
                (_currentCriteria.maxSleepDurationHours ?? 24).toString(),
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _currentCriteria = _currentCriteria.copyWith(
                    minSleepDurationHours: values.start.round(),
                    maxSleepDurationHours: values.end.round(),
                  );
                });
              },
            ),
            const SizedBox(height: 16),

            // 眠気の有無
            CheckboxListTile(
              title: const Text('日中の眠気'),
              value: _currentCriteria.hasDrowsiness ?? false,
              onChanged: (bool? value) {
                setState(() {
                  _currentCriteria = _currentCriteria.copyWith(hasDrowsiness: value);
                });
              },
            ),

            // 二度寝の有無
            CheckboxListTile(
              title: const Text('二度寝の有無'),
              value: _currentCriteria.hasOverslept ?? false,
              onChanged: (bool? value) {
                setState(() {
                  _currentCriteria = _currentCriteria.copyWith(hasOverslept: value);
                });
              },
            ),

            // 目標入眠時刻達成の有無
            CheckboxListTile(
              title: const Text('目標入眠時刻達成'),
              value: _currentCriteria.achievedGoal ?? false,
              onChanged: (bool? value) {
                setState(() {
                  _currentCriteria = _currentCriteria.copyWith(achievedGoal: value);
                });
              },
            ),
            const SizedBox(height: 16),

            // 日中の体感パフォーマンス
            Text('日中の体感パフォーマンス', style: Theme.of(context).textTheme.titleMedium),
            SegmentedButton<int?>(
              segments: const [
                ButtonSegment(value: null, label: Text('全て')),
                ButtonSegment(value: 1, label: Text('悪い')),
                ButtonSegment(value: 2, label: Text('普通')),
                ButtonSegment(value: 3, label: Text('良い')),
              ],
              selected: {_currentCriteria.performanceLevel},
              onSelectionChanged: (Set<int?> newSelection) {
                setState(() {
                  _currentCriteria = _currentCriteria.copyWith(performanceLevel: newSelection.first);
                });
              },
            ),
            const SizedBox(height: 16),

            // メモのハッシュタグ
            Text('メモのハッシュタグ検索', style: Theme.of(context).textTheme.titleMedium),
            TextField(
              controller: TextEditingController(text: _currentCriteria.hashtag),
              decoration: const InputDecoration(
                hintText: '#タグ名',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _currentCriteria = _currentCriteria.copyWith(hashtag: value.isEmpty ? null : value);
              },
            ),
            const SizedBox(height: 16),

            // 日付範囲 (提案)
            Text('日付範囲', style: Theme.of(context).textTheme.titleMedium),
            ElevatedButton(
              onPressed: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: _currentCriteria.startDate != null && _currentCriteria.endDate != null
                      ? DateTimeRange(start: _currentCriteria.startDate!, end: _currentCriteria.endDate!)
                      : null,
                );
                if (picked != null) {
                  setState(() {
                    _currentCriteria = _currentCriteria.copyWith(
                      startDate: picked.start,
                      endDate: picked.end,
                    );
                  });
                }
              },
              child: Text(
                _currentCriteria.startDate != null && _currentCriteria.endDate != null
                    ? '${DateFormat('yyyy/MM/dd').format(_currentCriteria.startDate!)} - ${DateFormat('yyyy/MM/dd').format(_currentCriteria.endDate!)}'
                    : '日付範囲を選択',
              ),
            ),
            const SizedBox(height: 16),

            // 睡眠スコア (提案)
            Text('睡眠スコア', style: Theme.of(context).textTheme.titleMedium),
            RangeSlider(
              values: RangeValues(
                (_currentCriteria.minSleepScore ?? 1).toDouble(),
                (_currentCriteria.maxSleepScore ?? 10).toDouble(),
              ),
              min: 1,
              max: 10,
              divisions: 9,
              labels: RangeLabels(
                (_currentCriteria.minSleepScore ?? 1).toString(),
                (_currentCriteria.maxSleepScore ?? 10).toString(),
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _currentCriteria = _currentCriteria.copyWith(
                    minSleepScore: values.start.round(),
                    maxSleepScore: values.end.round(),
                  );
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(SleepFilterCriteria()); // 全ての条件をリセット
          },
          child: const Text('リセット'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_currentCriteria);
          },
          child: const Text('適用'),
        ),
      ],
    );
  }
}
