import 'package:flutter/material.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item.dart';
import 'multi_gacha_result_screen.dart';

class SequentialGachaFlowScreen extends StatefulWidget {
  final List<GachaItem> items;
  final GachaConfig config;

  const SequentialGachaFlowScreen({
    super.key,
    required this.items,
    required this.config,
  });

  @override
  State<SequentialGachaFlowScreen> createState() => _SequentialGachaFlowScreenState();
}

class _SequentialGachaFlowScreenState extends State<SequentialGachaFlowScreen> {
  int _currentIndex = 0;

  void _onTapScreen() {
    if (_currentIndex < widget.items.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _navigateToSummary();
    }
  }

  void _navigateToSummary() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MultiGachaResultScreen(
          items: widget.items,
          config: widget.config,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final rarity = item.rarity;

    return GestureDetector(
      onTap: _onTapScreen,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: _navigateToSummary,
              child: const Text('結果一覧へスキップ'),
            ),
          ],
        ),
        body: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Column(
              key: ValueKey<int>(_currentIndex),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_currentIndex + 1} / ${widget.items.length}',
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Card(
                  color: rarity.color.withOpacity(0.3),
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: rarity.color, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          rarity.name,
                          style: TextStyle(
                            fontSize: 20,
                            color: rarity.color,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '"${item.text}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '- ${item.author} -',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'タップして次へ',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }
}