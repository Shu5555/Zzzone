import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Future<List<Map<String, dynamic>>> _rankingFuture;

  @override
  void initState() {
    super.initState();
    _rankingFuture = ApiService().getRanking();
  }

  String _formatDuration(int totalMinutes) {
    final duration = Duration(minutes: totalMinutes);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}時間 ${minutes}分';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('睡眠時間ランキング'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rankingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ランキングデータがまだありません。'));
          }

          final rankingData = snapshot.data!;

          return ListView.builder(
            itemCount: rankingData.length,
            itemBuilder: (context, index) {
              final entry = rankingData[index];
              final rank = index + 1;
              final username = entry['users']?['username'] ?? '名無しさん';
              final duration = entry['sleep_duration'] as int? ?? 0;

              return ListTile(
                leading: CircleAvatar(
                  child: Text('$rank'),
                ),
                title: Text(username),
                trailing: Text(
                  _formatDuration(duration),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
