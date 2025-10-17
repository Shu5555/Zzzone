import 'package:flutter/material.dart';
import '../services/supabase_ranking_service.dart';
import '../utils/date_helper.dart';
import 'ranking_quotes_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseRankingService _rankingService = SupabaseRankingService();
  late TabController _tabController;

  // To avoid re-fetching on every build, we hold futures in state variables.
  late Future<List<Map<String, dynamic>>> _sleepTimeRankingFuture;
  late Future<List<Map<String, dynamic>>> _aiScoreRankingFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRankings();
  }

  void _fetchRankings() {
    final date = getLogicalDateString(DateTime.now());
    _sleepTimeRankingFuture = _rankingService.getRanking(date: date);
    _aiScoreRankingFuture = _rankingService.getAiScoreRanking();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalMinutes) {
    final duration = Duration(minutes: totalMinutes);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}時間 ${minutes}分';
  }

  BoxDecoration _buildBackgroundDecoration(String? backgroundId) {
    Color backgroundColor;
    final id = backgroundId ?? 'default';

    if (id.startsWith('color_')) {
      final hexCode = id.replaceFirst('color_#', '');
      try {
        backgroundColor = Color(int.parse('0xff$hexCode'));
      } catch (e) {
        backgroundColor = Colors.transparent;
      }
    } else {
      backgroundColor = Colors.transparent;
    }
    return BoxDecoration(color: backgroundColor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ランキング'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '睡眠時間'),
            Tab(text: 'AIスコア'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSleepTimeRanking(),
          _buildAiScoreRanking(),
        ],
      ),
    );
  }

  Widget _buildSleepTimeRanking() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _sleepTimeRankingFuture,
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
            final user = entry['users'];
            if (user == null) return const SizedBox.shrink();

            return _buildRankingCard(
              rank: index + 1,
              username: user['username'] ?? '名無しさん',
              value: _formatDuration(entry['sleep_duration'] as int? ?? 0),
              backgroundId: user['background_preference'] as String?,
            );
          },
        );
      },
    );
  }

  Widget _buildAiScoreRanking() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _aiScoreRankingFuture,
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
            return _buildRankingCard(
              rank: index + 1,
              username: entry['username'] ?? '名無しさん',
              value: '${entry['score'] ?? 0} 点',
              backgroundId: entry['background_preference'] as String?,
            );
          },
        );
      },
    );
  }

  Widget _buildRankingCard({
    required int rank,
    required String username,
    required String value,
    String? backgroundId,
  }) {
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
          Positioned.fill(
            child: Container(decoration: _buildBackgroundDecoration(backgroundId)),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),
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
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                    color: Colors.white,
                    shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}