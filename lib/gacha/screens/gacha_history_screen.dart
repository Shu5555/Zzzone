import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sleep_management_app/models/gacha_pull_record.dart';
import '../../services/database_helper.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item.dart';
import '../services/gacha_data_loader.dart';

class GachaHistoryScreen extends StatefulWidget {
  const GachaHistoryScreen({super.key});

  @override
  State<GachaHistoryScreen> createState() => _GachaHistoryScreenState();
}

class _GachaHistoryScreenState extends State<GachaHistoryScreen> {
  late Future<HistoryData> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _loadHistory();
  }

  Future<HistoryData> _loadHistory() async {
    final history = await DatabaseHelper.instance.getGachaHistory();
    final allItems = await GachaDataLoader.loadItems('assets/gacha/gacha_items.json');
    final config = await GachaDataLoader.loadConfig('assets/gacha/gacha_config.json');
    return HistoryData(history: history, allItems: allItems, config: config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ガチャ履歴'),
      ),
      body: FutureBuilder<HistoryData>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.history.isEmpty) {
            return const Center(child: Text('まだガチャを引いていません'));
          }

          final data = snapshot.data!;

          return ListView.builder(
            itemCount: data.history.length,
            itemBuilder: (context, index) {
              final pullRecord = data.history[index];
              final item = data.allItems.firstWhere(
                (i) => i.id == pullRecord.quoteId,
                orElse: () => GachaItem(id: 'not_found', rarityId: 'common'),
              );
              final rarity = data.config.rarities.firstWhere(
                (r) => r.id == pullRecord.rarityId,
              );

              return ListTile(
                title: Text('"${item.text}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                subtitle: Text('- ${item.author}'),
                leading: Text(
                  DateFormat('MM/dd\nHH:mm').format(pullRecord.pulledAt),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                trailing: Text(
                  rarity.name,
                  style: TextStyle(
                    color: rarity.color,
                    fontWeight: FontWeight.bold,
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

class HistoryData {
  final List<GachaPullRecord> history;
  final List<GachaItem> allItems;
  final GachaConfig config;

  HistoryData({required this.history, required this.allItems, required this.config});
}
