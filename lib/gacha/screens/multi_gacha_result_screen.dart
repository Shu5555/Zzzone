import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/gacha_config.dart';
import '../models/gacha_item.dart';
import '../models/gacha_item_with_new_status.dart';

class MultiGachaResultScreen extends StatelessWidget {
  final List<GachaItemWithNewStatus> itemsWithStatus;
  final GachaConfig config;

  const MultiGachaResultScreen({
    super.key,
    required this.itemsWithStatus,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final rarityCounts = <String, int>{};
    int highestOrder = 0;

    for (var itemWithStatus in itemsWithStatus) {
      final finalItem = itemWithStatus.finalItem;
      rarityCounts[finalItem.rarityId] = (rarityCounts[finalItem.rarityId] ?? 0) + 1;
      if (finalItem.rarity.order > highestOrder) {
        highestOrder = finalItem.rarity.order;
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
                final itemWithStatus = itemsWithStatus[index];
                final item = itemWithStatus.finalItem;
                final rarity = item.rarity;
                final bool isNew = itemWithStatus.isNew;
                final bool didPromote = itemWithStatus.didPromote;
                final isHighest = rarity.order == highestOrder;

                return Card(
                  color: rarity.color.withOpacity(0.2),
                  elevation: isHighest ? 8 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isHighest ? BorderSide(color: rarity.color, width: 2) : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias, // To make banners clip correctly
                  child: Stack(
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
                      if (isNew)
                        _Banner(text: 'NEW!', color: Colors.redAccent),
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

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  final Alignment alignment;

  const _Banner({
    required this.text,
    required this.color,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: ClipPath(
          clipper: _BannerClipper(),
          child: Container(
            width: 45, // Increased size
            height: 45, // Increased size
            color: color,
            child: Center(
              child: Transform.rotate(
                angle: alignment == Alignment.topLeft ? -math.pi / 4 : math.pi / 4,
                origin: const Offset(10, 10), // Adjust origin
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9, // Smaller font
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}