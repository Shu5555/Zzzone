import 'package:flutter/material.dart';
import '../services/supabase_ranking_service.dart';
import '../utils/date_helper.dart'; // Import the date helper
import 'ranking_quotes_screen.dart'; // Import the new screen

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
    _rankingFuture = SupabaseRankingService().getRanking(date: getLogicalDateString(DateTime.now()));
  }

  String _formatDuration(int totalMinutes) {
    final duration = Duration(minutes: totalMinutes);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}時間 ${minutes}分';
  }

  BoxDecoration _buildBackgroundDecoration(String backgroundId) {
    Color backgroundColor;

    if (backgroundId.startsWith('color_')) {
      final hexCode = backgroundId.replaceFirst('color_#', '');
      try {
        backgroundColor = Color(int.parse('0xff$hexCode'));
      } catch (e) {
        backgroundColor = Colors.transparent; // Fallback to transparent
      }
    } else {
      // Handles 'default' and any legacy pattern IDs by making the background transparent.
      backgroundColor = Colors.transparent;
    }
    return BoxDecoration(color: backgroundColor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('睡眠時間ランキング'),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_quote),
            tooltip: '名言ランキング',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RankingQuotesScreen()),
              );
            },
          ),
        ],
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
              final user = entry['users'];
              if (user == null) return const SizedBox.shrink();

              final username = user['username'] ?? '名無しさん';
              final duration = entry['sleep_duration'] as int? ?? 0;
              final backgroundId = user['background_preference'] as String? ?? 'default';

              Widget? leadingIcon;
              TextStyle? titleStyle;
              TextStyle? rankStyle;

              if (rank == 1) {
                leadingIcon = Icon(Icons.emoji_events, color: Colors.yellow[600]);
                titleStyle = const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, shadows: [Shadow(blurRadius: 3, color: Colors.black)]);
                rankStyle = const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 3, color: Colors.black)]);
              } else if (rank == 2) {
                leadingIcon = Icon(Icons.emoji_events, color: Colors.grey[300]);
                titleStyle = const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white, shadows: [Shadow(blurRadius: 3, color: Colors.black)]);
                rankStyle = const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 3, color: Colors.black)]);
              } else if (rank == 3) {
                leadingIcon = Icon(Icons.emoji_events, color: Colors.orange[300]);
                titleStyle = const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, shadows: [Shadow(blurRadius: 3, color: Colors.black)]);
                rankStyle = const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 3, color: Colors.black)]);
              } else {
                titleStyle = const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black)]);
                rankStyle = const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black)]);
              }

              return Card(
                elevation: rank <= 3 ? 4.0 : 1.0,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Layer 1: Background (Image or Color)
                    Positioned.fill(
                      child: Container(decoration: _buildBackgroundDecoration(backgroundId)),
                    ),
                    // Layer 2: Gradient Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.transparent
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: const [0.0, 0.8],
                          ),
                        ),
                      ),
                    ),
                    // Layer 3: Content
                    ListTile(
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$rank位', style: rankStyle),
                          if (leadingIcon != null) leadingIcon,
                        ],
                      ),
                      title: Text(username, style: titleStyle),
                      trailing: Text(
                        _formatDuration(duration),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                              color: Colors.white,
                              shadows: const [Shadow(blurRadius: 2, color: Colors.black)]
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
