import 'package:flutter/material.dart';
import '../gacha/models/gacha_item.dart';
import '../gacha/services/gacha_data_loader.dart';
import '../services/supabase_ranking_service.dart';
import '../utils/date_helper.dart';

class RankingQuotesScreen extends StatefulWidget {
  const RankingQuotesScreen({super.key});

  @override
  State<RankingQuotesScreen> createState() => _RankingQuotesScreenState();
}

class _RankingQuotesScreenState extends State<RankingQuotesScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final ranking = await SupabaseRankingService().getRankingWithQuotes(date: getLogicalDateString(DateTime.now()));
    final allItems = await GachaDataLoader.loadItems('assets/gacha/gacha_items.json');
    
    final allItemsMap = {for (var item in allItems) item.id: item};

    return {
      'ranking': ranking,
      'quotesMap': allItemsMap,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('名言ランキング'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || (snapshot.data!['ranking'] as List).isEmpty) {
            return const Center(child: Text('ランキングデータがありません。'));
          }

          final rankingData = snapshot.data!['ranking'] as List<Map<String, dynamic>>;
          final quotesMap = snapshot.data!['quotesMap'] as Map<String, GachaItem>;

          return ListView.builder(
            itemCount: rankingData.length,
            itemBuilder: (context, index) {
              final entry = rankingData[index];
              final rank = index + 1;
              final username = entry['username'] ?? '名無しさん';
              final favoriteQuoteId = entry['favorite_quote_id'];

              GachaItem? quote;
              if (favoriteQuoteId != null && favoriteQuoteId != 'random') {
                quote = quotesMap[favoriteQuoteId];
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$rank位: $username さん',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (quote != null)
                        ...[
                          Text(
                            '"${quote.text}"',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('- ${quote.author}'),
                          ),
                        ]
                      else
                        Text(
                          '名言が設定されていません',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                    ],
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