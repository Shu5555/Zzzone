import 'package:flutter/material.dart';
import 'dart:async';
import '../models/gacha_config.dart';
import '../models/gacha_item_with_new_status.dart';
import '../animations/three_gacha_animation_screen.dart';
import 'single_gacha_result_view.dart';
import 'multi_gacha_result_screen.dart';

class GachaSequenceController extends StatefulWidget {
  final List<GachaItemWithNewStatus> itemsWithStatus;
  final GachaConfig config;

  const GachaSequenceController({
    super.key,
    required this.itemsWithStatus,
    required this.config,
  });

  @override
  State<GachaSequenceController> createState() => _GachaSequenceControllerState();
}

class _GachaSequenceControllerState extends State<GachaSequenceController> {
  int _currentIndex = 0;
  final List<bool> _openedOrbs = [];

  @override
  void initState() {
    super.initState();
    _openedOrbs.addAll(List.filled(widget.itemsWithStatus.length, false));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNextAnimation();
    });
  }

  void _showNextAnimation() {
    if (!mounted) return;

    if (_currentIndex >= widget.itemsWithStatus.length) {
      _navigateToSummary();
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => ThreeGachaAnimationScreen(
          key: ValueKey(_currentIndex),
          itemsWithStatus: widget.itemsWithStatus,
          config: widget.config,
          indexToFocus: _currentIndex,
          openedOrbs: _openedOrbs,
          isIntro: _currentIndex == 0,
          onAnimationComplete: () {
            if (mounted) {
              Navigator.pop(context);
              setState(() {
                _openedOrbs[_currentIndex] = true;
              });
              _showNextResult();
            }
          },
          onSkip: _navigateToSummary, // Add this line
        ),
      ),
    );
  }

  void _showNextResult() {
    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.pop(context);
            setState(() {
              _currentIndex++;
            });
            _showNextAnimation();
          },
          child: SingleGachaResultView(
            itemWithStatus: widget.itemsWithStatus[_currentIndex],
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToSummary() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MultiGachaResultScreen(
          itemsWithStatus: widget.itemsWithStatus,
          config: widget.config,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
