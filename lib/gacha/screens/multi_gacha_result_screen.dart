import 'package:flutter/material.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item.dart';

class MultiGachaResultScreen extends StatelessWidget {
  final List<GachaItem> items;
  final GachaConfig config;

  const MultiGachaResultScreen({
    super.key,
    required this.items,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final rarityCounts = <String, int>{};
    for (var item in items) {
      rarityCounts[item.rarityId] = (rarityCounts[item.rarityId] ?? 0) + 1;
    }

    int highestOrder = 0;
    for (var item in items) {
      final rarity = config.rarities.firstWhere((r) => r.id == item.rarityId);
      if (rarity.name.length > highestOrder) { // A simple way to find a 'high' rarity without order
        highestOrder = rarity.name.length;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${config.multiPullCount}連ガチャ結果'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: rarityCounts.entries.map((entry) {
                final rarity = config.rarities.firstWhere((r) => r.id == entry.key);
                return Chip(
                  label: Text('${rarity.name} x${entry.value}', style: const TextStyle(color: Colors.white)),
                  backgroundColor: rarity.color,
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final rarity = item.rarity;
                final isHighest = rarity.name.length == highestOrder;

                return Card(
                  color: rarity.color.withOpacity(0.2),
                  elevation: isHighest ? 8 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isHighest ? BorderSide(color: rarity.color, width: 2) : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          '"${item.text}"',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: rarity.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rarity.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('閉じる'),
            ),
          ),
        ],
      ),
    );
  }
}
