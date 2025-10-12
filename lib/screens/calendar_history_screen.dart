import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import '../utils/date_helper.dart';
import 'sleep_edit_screen.dart';

class CalendarHistoryScreen extends StatefulWidget {
  const CalendarHistoryScreen({super.key});

  @override
  State<CalendarHistoryScreen> createState() => _CalendarHistoryScreenState();
}

class _CalendarHistoryScreenState extends State<CalendarHistoryScreen> {
  late final Future<void> _initFuture;
  Map<DateTime, List<SleepRecord>> _recordsByDate = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<SleepRecord> _selectedRecords = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initFuture = _loadRecordsAndInitSelection();
  }

  Future<void> _loadRecordsAndInitSelection() async {
    final records = await DatabaseHelper.instance.readAllRecords();
    if (mounted) {
      setState(() {
        _recordsByDate = _groupRecordsByDate(records);
        _selectedRecords = _getRecordsForDay(_selectedDay!);
      });
    }
  }

  Map<DateTime, List<SleepRecord>> _groupRecordsByDate(List<SleepRecord> records) {
    final Map<DateTime, List<SleepRecord>> data = {};
    for (final record in records) {
      final date = record.recordDate;
      if (data[date] == null) data[date] = [];
      data[date]!.add(record);
    }
    return data;
  }

  List<SleepRecord> _getRecordsForDay(DateTime day) {
    return _recordsByDate[DateUtils.dateOnly(day)] ?? [];
  }

  void _navigateToEditScreen(SleepRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SleepEditScreen(existingRecord: record)),
    );
    _loadRecordsAndInitSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー履歴')),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _recordsByDate.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }

          return Column(
            children: [
              TableCalendar<SleepRecord>(
                locale: 'ja_JP',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                eventLoader: _getRecordsForDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _selectedRecords = _getRecordsForDay(selectedDay);
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                ),
                calendarBuilders: CalendarBuilders(markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return _buildDonutChart(day, events);
                }),
              ),
              const Divider(),
              Expanded(
                child: _selectedRecords.isEmpty
                    ? const Center(child: Text('この日の記録はありません。'))
                    : ListView.builder(
                        itemCount: _selectedRecords.length,
                        itemBuilder: (context, index) {
                          final record = _selectedRecords[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              onLongPress: () => _navigateToEditScreen(record),
                              onTap: null, // タップは無効化
                              title: Row(children: [
                                Expanded(
                                  child: Text(
                                    '${DateFormat('M/d(E)', 'ja_JP').format(record.recordDate)}の睡眠',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (record.hasAchievedGoal) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.emoji_events, color: Colors.amber, size: 20)),
                                if (!record.didNotOversleep) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.snooze, color: Colors.grey, size: 20)),
                                if (record.hadDaytimeDrowsiness) const Padding(padding: EdgeInsets.only(left: 4.0), child: Text('😴', style: TextStyle(fontSize: 16))),
                              ]),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Builder(builder: (context) {
                                    String performanceText;
                                    switch (record.performance) {
                                      case 1:
                                        performanceText = '悪い';
                                        break;
                                      case 3:
                                        performanceText = '良い';
                                        break;
                                      default:
                                        performanceText = '普通';
                                    }
                                    return Text('''睡眠時間: ${DateFormat.Hm().format(record.sleepTime)} - ${DateFormat.Hm().format(record.wakeUpTime)} (${record.duration.inHours}h ${record.duration.inMinutes.remainder(60)}m)
スコア: ${record.score}, パフォーマンス: $performanceText''');
                                  }),
                                  if (record.memo != null && record.memo!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 8.0),
                                      padding: const EdgeInsets.all(8.0),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(
                                        record.memo!,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDonutChart(DateTime day, List<SleepRecord> records) {
    final totalDurationInMinutes = records.fold<double>(0, (sum, record) => sum + record.duration.inMinutes);
    final sleepHours = totalDurationInMinutes / 60.0;
    final color = sleepHours >= 7 ? Colors.green : (sleepHours >= 6 ? Colors.blue : Colors.orange);

    const double goalInMinutes = 8 * 60;
    final percentage = (totalDurationInMinutes / goalInMinutes).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(width: 2, color: color.withOpacity(0.5))),
      child: Center(
        child: PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(value: percentage, color: color, radius: 5, showTitle: false),
              PieChartSectionData(value: 1 - percentage, color: Colors.grey.withOpacity(0.2), radius: 5, showTitle: false),
            ],
            centerSpaceRadius: 8,
            startDegreeOffset: -90,
            sectionsSpace: 0,
          ),
        ),
      ),
    );
  }
}