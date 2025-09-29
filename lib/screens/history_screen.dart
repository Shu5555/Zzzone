import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import '../utils/date_helper.dart';
import 'post_sleep_input_screen.dart';
import 'calendar_history_screen.dart';
import 'analysis_report_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('睡眠の履歴'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '週表示'),
              Tab(text: '月表示'),
              Tab(text: '分析レポート'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            WeeklyHistoryView(),
            MonthlyHistoryView(),
            AnalysisReportView(),
          ],
        ),
      ),
    );
  }
}

// --- 週表示ウィジェット ---
class WeeklyHistoryView extends StatefulWidget {
  const WeeklyHistoryView({super.key});
  @override
  State<WeeklyHistoryView> createState() => _WeeklyHistoryViewState();
}

class _WeeklyHistoryViewState extends State<WeeklyHistoryView> {
  late Future<List<SleepRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    setState(() {
      _recordsFuture = DatabaseHelper.instance.readAllRecords();
    });
  }

  void _navigateToEditScreen(SleepRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => PostSleepInputScreen(initialRecord: record)),
    );
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SleepRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('エラー: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('記録なし'));

        final allRecords = snapshot.data!;
        final today = getLogicalDate(DateTime.now());
        final recordsForDisplay = allRecords.where((r) => today.difference(getLogicalDate(r.sleepTime)).inDays < 7).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('過去7日間の睡眠時間', style: Theme.of(context).textTheme.titleLarge),
            ),
            AspectRatio(
              aspectRatio: 1.7,
              child: recordsForDisplay.isEmpty
                  ? const Center(child: Text('データなし'))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildWeeklyChart(recordsForDisplay),
                    ),
            ),
            const Divider(),
            _buildStatistics(recordsForDisplay),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: recordsForDisplay.length,
                itemBuilder: (context, index) {
                  final record = recordsForDisplay[index];
                  return _buildRecordTile(record);
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildRecordTile(SleepRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildListDonutChart(record),
        title: Row(children: [
          Expanded(
            child: Text(
              '${DateFormat('M/d(E)', 'ja_JP').format(getLogicalDate(record.sleepTime))}の睡眠',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (record.hasAchievedGoal) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.emoji_events, color: Colors.amber, size: 20)),
          if (!record.didNotOversleep) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.snooze, color: Colors.grey, size: 20)),
          if (record.hadDaytimeDrowsiness) const Padding(padding: EdgeInsets.only(left: 4.0), child: Text('😴', style: TextStyle(fontSize: 16))),
        ]),
        subtitle: Text('''睡眠時間: ${record.duration.inHours}h ${record.duration.inMinutes.remainder(60)}m
${DateFormat('HH:mm').format(record.sleepTime)} - ${DateFormat('HH:mm').format(record.wakeUpTime)}'''),
        onLongPress: () => _navigateToEditScreen(record),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildListDonutChart(SleepRecord record) {
    final sleepHours = record.duration.inMinutes / 60.0;
    final color = sleepHours >= 7 ? Colors.green : (sleepHours >= 6 ? Colors.blue : Colors.orange);
    final percentage = (record.duration.inMinutes / (8 * 60)).clamp(0.0, 1.0);
    return SizedBox(
      width: 40, height: 40,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(value: percentage, color: color, radius: 8, showTitle: false),
            PieChartSectionData(value: 1 - percentage, color: Colors.grey.withOpacity(0.2), radius: 8, showTitle: false),
          ],
          centerSpaceRadius: 12, startDegreeOffset: -90, sectionsSpace: 0,
        ),
      ),
    );
  }

  Widget _buildStatistics(List<SleepRecord> records) {
    if (records.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _buildGoalStatistics(records),
        const SizedBox(height: 8),
        _buildScoreAnalysis(records),
      ],
    );
  }

  Widget _buildGoalStatistics(List<SleepRecord> records) {
    final achievedCount = records.where((r) => r.hasAchievedGoal).length;
    final totalCount = records.length;
    final achievementRate = totalCount > 0 ? (achievedCount / totalCount) * 100 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('目標達成率', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${achievementRate.toStringAsFixed(1)} % ($totalCount日中 $achievedCount日 達成)', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildScoreAnalysis(List<SleepRecord> records) {
    if (records.length < 2) return const SizedBox.shrink();
    double calculateAverageScore(List<SleepRecord> list) {
      if (list.isEmpty) return 0.0;
      return list.map((r) => r.score).reduce((a, b) => a + b) / list.length;
    }
    final achievedRecords = records.where((r) => r.hasAchievedGoal).toList();
    final notAchievedRecords = records.where((r) => !r.hasAchievedGoal).toList();
    final didNotOversleepRecords = records.where((r) => r.didNotOversleep).toList();
    final oversleptRecords = records.where((r) => !r.didNotOversleep).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('スコア分析', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAnalysisItem('目標達成時', calculateAverageScore(achievedRecords)),
              _buildAnalysisItem('未達成時', calculateAverageScore(notAchievedRecords)),
              _buildAnalysisItem('二度寝なし', calculateAverageScore(didNotOversleepRecords)),
              _buildAnalysisItem('二度寝あり', calculateAverageScore(oversleptRecords)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String label, double score) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          score > 0 ? score.toStringAsFixed(1) : '-',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(List<SleepRecord> records) {
    final chartData = _generateWeeklyChartData(records);
    if (chartData.isEmpty) return const Center(child: Text('データがありません'));
    final maxSleepHours = chartData.map((d) => d.barRods.first.toY).fold(0.0, (p, c) => max(p, c));
    final yAxisMax = max(8.0, (maxSleepHours.ceil() + 1).toDouble());
    return BarChart(
      BarChartData(
        maxY: yAxisMax,
        barGroups: chartData,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final day = DateFormat('M/d').format(getLogicalDate(DateTime.now()).subtract(Duration(days: 6 - value.toInt())));
                return SideTitleWidget(axisSide: meta.axisSide, child: Text(day, style: const TextStyle(fontSize: 10)));
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value > yAxisMax) return Container();
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final hours = rod.toY;
              return BarTooltipItem('${hours.toStringAsFixed(1)} 時間', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
            },
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateWeeklyChartData(List<SleepRecord> records) {
    final List<double> dailySleep = List.filled(7, 0.0);
    final today = getLogicalDate(DateTime.now());
    for (final record in records) {
      final recordDate = getLogicalDate(record.sleepTime);
      final difference = today.difference(recordDate).inDays;
      if (difference >= 0 && difference < 7) {
        dailySleep[6 - difference] += record.duration.inMinutes / 60.0;
      }
    }
    return List.generate(7, (index) {
      final sleepHours = dailySleep[index];
      final color = sleepHours >= 7 ? Colors.green : (sleepHours >= 6 ? Colors.blue : Colors.orange);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: sleepHours,
            color: color,
            width: 16,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          ),
        ],
      );
    });
  }
}

// --- 月表示ウィジェット ---
class MonthlyHistoryView extends StatefulWidget {
  const MonthlyHistoryView({super.key});
  @override
  State<MonthlyHistoryView> createState() => _MonthlyHistoryViewState();
}

class _MonthlyHistoryViewState extends State<MonthlyHistoryView> {
  late Future<List<SleepRecord>> _recordsFuture;
  DateTime _displayMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    setState(() {
      _recordsFuture = DatabaseHelper.instance.readAllRecords();
    });
  }

  void _changeMonth(int month) {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + month);
    });
  }

  void _navigateToEditScreen(SleepRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => PostSleepInputScreen(initialRecord: record)),
    );
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SleepRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('エラー: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('記録なし'));

        final allRecords = snapshot.data!;
        final recordsForDisplay = allRecords.where((r) => getLogicalDate(r.sleepTime).year == _displayMonth.year && getLogicalDate(r.sleepTime).month == _displayMonth.month).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.arrow_left), onPressed: () => _changeMonth(-1)),
                Text(DateFormat.yMMM('ja_JP').format(_displayMonth), style: Theme.of(context).textTheme.titleLarge),
                IconButton(icon: const Icon(Icons.arrow_right), onPressed: () => _changeMonth(1)),
              ],
            ),
            AspectRatio(
              aspectRatio: 1.7,
              child: recordsForDisplay.isEmpty
                  ? const Center(child: Text('データなし'))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildMonthlyChart(recordsForDisplay, _displayMonth),
                    ),
            ),
            const Divider(),
            _buildStatistics(recordsForDisplay),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CalendarHistoryScreen()),
                    );
                  },
                  child: const Text('カレンダーで全て見る >'),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recordsForDisplay.length,
                itemBuilder: (context, index) {
                  final record = recordsForDisplay[index];
                  return _buildRecordTile(record);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordTile(SleepRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildListDonutChart(record),
        title: Row(children: [
          Expanded(
            child: Text(
              '${DateFormat('M/d(E)', 'ja_JP').format(getLogicalDate(record.sleepTime))}の睡眠',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (record.hasAchievedGoal) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.emoji_events, color: Colors.amber, size: 20)),
          if (!record.didNotOversleep) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.snooze, color: Colors.grey, size: 20)),
          if (record.hadDaytimeDrowsiness) const Padding(padding: EdgeInsets.only(left: 4.0), child: Text('😴', style: TextStyle(fontSize: 16))),
        ]),
        subtitle: Text('''睡眠時間: ${record.duration.inHours}h ${record.duration.inMinutes.remainder(60)}m
${DateFormat('HH:mm').format(record.sleepTime)} - ${DateFormat('HH:mm').format(record.wakeUpTime)}'''),
        onLongPress: () => _navigateToEditScreen(record),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildListDonutChart(SleepRecord record) {
    final sleepHours = record.duration.inMinutes / 60.0;
    final color = sleepHours >= 7 ? Colors.green : (sleepHours >= 6 ? Colors.blue : Colors.orange);
    final percentage = (record.duration.inMinutes / (8 * 60)).clamp(0.0, 1.0);
    return SizedBox(
      width: 40, height: 40,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(value: percentage, color: color, radius: 8, showTitle: false),
            PieChartSectionData(value: 1 - percentage, color: Colors.grey.withOpacity(0.2), radius: 8, showTitle: false),
          ],
          centerSpaceRadius: 12, startDegreeOffset: -90, sectionsSpace: 0,
        ),
      ),
    );
  }

  Widget _buildStatistics(List<SleepRecord> records) {
    if (records.isEmpty) return const SizedBox(height: 50, child: Center(child: Text("データがありません")));
    return Column(
      children: [
        _buildGoalStatistics(records),
        const SizedBox(height: 8),
        _buildScoreAnalysis(records),
      ],
    );
  }

  Widget _buildGoalStatistics(List<SleepRecord> records) {
    final achievedCount = records.where((r) => r.hasAchievedGoal).length;
    final totalCount = records.length;
    final achievementRate = totalCount > 0 ? (achievedCount / totalCount) * 100 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('目標達成率', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${achievementRate.toStringAsFixed(1)} % ($totalCount日中 $achievedCount日 達成)', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildScoreAnalysis(List<SleepRecord> records) {
    if (records.length < 2) return const SizedBox.shrink();
    double calculateAverageScore(List<SleepRecord> list) {
      if (list.isEmpty) return 0.0;
      return list.map((r) => r.score).reduce((a, b) => a + b) / list.length;
    }
    final achievedRecords = records.where((r) => r.hasAchievedGoal).toList();
    final notAchievedRecords = records.where((r) => !r.hasAchievedGoal).toList();
    final didNotOversleepRecords = records.where((r) => r.didNotOversleep).toList();
    final oversleptRecords = records.where((r) => !r.didNotOversleep).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('スコア分析', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAnalysisItem('目標達成時', calculateAverageScore(achievedRecords)),
              _buildAnalysisItem('未達成時', calculateAverageScore(notAchievedRecords)),
              _buildAnalysisItem('二度寝なし', calculateAverageScore(didNotOversleepRecords)),
              _buildAnalysisItem('二度寝あり', calculateAverageScore(oversleptRecords)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String label, double score) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          score > 0 ? score.toStringAsFixed(1) : '-',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart(List<SleepRecord> records, DateTime displayMonth) {
    final chartData = _generateMonthlyChartData(records, displayMonth);
    if (chartData.isEmpty) return const Center(child: Text('データがありません'));
    final maxSleepHours = chartData.map((d) => d.barRods.first.toY).fold(0.0, (p, c) => max(p, c));
    final yAxisMax = max(8.0, (maxSleepHours.ceil() + 1).toDouble());
    return BarChart(
      BarChartData(
        maxY: yAxisMax,
        barGroups: chartData,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final day = value.toInt() + 1;
                if (day % 5 == 0 || day == 1) {
                  return SideTitleWidget(axisSide: meta.axisSide, child: Text(day.toString(), style: const TextStyle(fontSize: 10)));
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value > yAxisMax) return Container();
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final hours = rod.toY;
              return BarTooltipItem('${group.x + 1}日: ${hours.toStringAsFixed(1)} 時間', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
            },
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateMonthlyChartData(List<SleepRecord> records, DateTime displayMonth) {
    final daysInMonth = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);
    final List<double> dailySleep = List.filled(daysInMonth, 0.0);
    for (final record in records) {
      final logicalDate = getLogicalDate(record.sleepTime);
      if (logicalDate.year == displayMonth.year && logicalDate.month == displayMonth.month) {
        dailySleep[logicalDate.day - 1] += record.duration.inMinutes / 60.0;
      }
    }
    return List.generate(daysInMonth, (index) {
      final sleepHours = dailySleep[index];
      final color = sleepHours >= 7 ? Colors.green : (sleepHours >= 6 ? Colors.blue : Colors.orange);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: sleepHours,
            color: color,
            width: 8,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          ),
        ],
      );
    });
  }
}
