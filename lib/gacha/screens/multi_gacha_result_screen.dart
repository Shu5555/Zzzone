import 'package:flutter/material.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item.dart';
import '../models/gacha_item_with_new_status.dart'; // Import GachaItemWithNewStatus

class MultiGachaResultScreen extends StatelessWidget {
  final List<GachaItemWithNewStatus> itemsWithStatus; // Change this line
  final GachaConfig config;

  const MultiGachaResultScreen({
    super.key,
    required this.itemsWithStatus, // Change this line
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final rarityCounts = <String, int>{};
    for (var itemWithStatus in itemsWithStatus) { // Iterate through itemsWithStatus
      rarityCounts[itemWithStatus.item.rarityId] = (rarityCounts[itemWithStatus.item.rarityId] ?? 0) + 1;
    }

    int highestOrder = 0;
    for (var itemWithStatus in itemsWithStatus) { // Iterate through itemsWithStatus
      final rarity = config.rarities.firstWhere((r) => r.id == itemWithStatus.item.rarityId); // Use itemWithStatus.item
      if (rarity.name.length > highestOrder) {
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
              itemCount: itemsWithStatus.length,
              itemBuilder: (context, index) {
                final itemWithStatus = itemsWithStatus[index]; // Get GachaItemWithNewStatus
                final item = itemWithStatus.item; // Get the GachaItem
                final rarity = item.rarity;
                final bool isNew = itemWithStatus.isNew; // Get the isNew status
                final isHighest = rarity.name.length == highestOrder;

                return Card(
                  color: rarity.color.withOpacity(0.2),
                  elevation: isHighest ? 8 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isHighest ? BorderSide(color: rarity.color, width: 2) : BorderSide.none,
                  ),
                  child: Stack( // "NEW!" を重ねるために Stack を使用
                    children: [
                      Padding(
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
                      if (isNew) // "NEW!" を条件付きで表示
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'NEW!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
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
