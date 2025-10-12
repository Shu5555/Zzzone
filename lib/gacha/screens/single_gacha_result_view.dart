import 'package:flutter/material.dart';
import '../models/gacha_item_with_new_status.dart';

class SingleGachaResultView extends StatelessWidget {
  final GachaItemWithNewStatus itemWithStatus;

  const SingleGachaResultView({super.key, required this.itemWithStatus});

  @override
  Widget build(BuildContext context) {
    final item = itemWithStatus.finalItem; // Always display the final item
    final didPromote = itemWithStatus.didPromote;
    final rarity = item.rarity;
    final isNew = itemWithStatus.isNew;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'NEW!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (isNew) const SizedBox(height: 15),
              Text(
                rarity.name,
                style: TextStyle(
                  fontSize: 24,
                  color: rarity.color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '"${item.text}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '- ${item.author} -',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(30.0),
        child: Text(
          'タップして続ける',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
