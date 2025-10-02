import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_helper.dart'; // Import the date helper

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
    // Pass today's logical date to the getRanking method
    _rankingFuture = ApiService().getRanking(getLogicalDateString(DateTime.now()));
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

              // 上位3位の装飾を定義
              Widget? leadingIcon;
              TextStyle? titleStyle;
              TextStyle? rankStyle; // 順位のスタイルを追加
              Color? specialColor; // 上位3位用の色を追加

              if (rank == 1) {
                leadingIcon = Icon(Icons.emoji_events, color: Colors.amber[600]);
                specialColor = Colors.amber[800];
                titleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: specialColor);
                rankStyle = TextStyle(fontWeight: FontWeight.bold, color: specialColor);
              } else if (rank == 2) {
                leadingIcon = Icon(Icons.emoji_events, color: Colors.grey[400]);
                specialColor = Colors.grey[700];
                titleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: specialColor);
                rankStyle = TextStyle(fontWeight: FontWeight.bold, color: specialColor);
              } else if (rank == 3) {
                leadingIcon = Icon(Icons.emoji_events, color: Colors.brown[400]);
                specialColor = Colors.brown[700];
                titleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: specialColor);
                rankStyle = TextStyle(fontWeight: FontWeight.bold, color: specialColor);
              }

              return Card(
                elevation: rank <= 3 ? 4.0 : 1.0,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$rank位', style: rankStyle ?? const TextStyle(fontWeight: FontWeight.bold)),
                      if (leadingIcon != null) leadingIcon,
                    ],
                  ),
                  title: Text(username, style: titleStyle),
                  trailing: Text(
                    _formatDuration(duration),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                          color: specialColor, // 色を適用
                        ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
