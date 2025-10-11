import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gacha_item.dart';
import 'gacha_result_screen.dart';

class GachaAnimationScreen extends StatefulWidget {
  final GachaItem item;
  final bool isNew;

  const GachaAnimationScreen({
    super.key,
    required this.item,
    this.isNew = false,
  });

  @override
  State<GachaAnimationScreen> createState() => _GachaAnimationScreenState();
}

class _GachaAnimationScreenState extends State<GachaAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Navigate to the result screen after a delay
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GachaResultScreen(
              item: widget.item,
              isNew: widget.isNew,
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
    final rarity = widget.item.rarity;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: rarity.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: rarity.color.withOpacity(0.7),
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
