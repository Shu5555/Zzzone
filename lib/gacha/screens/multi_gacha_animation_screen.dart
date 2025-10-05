import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item.dart';
import '../models/gacha_rarity.dart';
import 'sequential_gacha_flow_screen.dart';

class MultiGachaAnimationScreen extends StatefulWidget {
  final List<GachaItem> items;
  final GachaConfig config;

  const MultiGachaAnimationScreen({
    super.key,
    required this.items,
    required this.config,
  });

  @override
  State<MultiGachaAnimationScreen> createState() => _MultiGachaAnimationScreenState();
}

class _MultiGachaAnimationScreenState extends State<MultiGachaAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late GachaRarity _highestRarity;

  @override
  void initState() {
    super.initState();

    // Find the highest rarity in the pulled items
    _highestRarity = widget.items.map((item) => item.rarity).reduce((a, b) => a.order > b.order ? a : b);

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Navigate to the sequential result screen after a delay
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SequentialGachaFlowScreen(
              items: widget.items,
              config: widget.config,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _highestRarity.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _highestRarity.color.withOpacity(0.7),
                  blurRadius: 20.0,
                  spreadRadius: 5.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}