import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item_with_new_status.dart';
import 'single_gacha_result_view.dart';
import 'multi_gacha_result_screen.dart';

class GachaOrchestratorScreen extends StatefulWidget {
  final List<GachaItemWithNewStatus> itemsWithStatus;
  final GachaConfig config;

  const GachaOrchestratorScreen({
    super.key,
    required this.itemsWithStatus,
    required this.config,
  });

  @override
  State<GachaOrchestratorScreen> createState() => _GachaOrchestratorScreenState();
}

class _GachaOrchestratorScreenState extends State<GachaOrchestratorScreen>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _focusController;
  late AnimationController _promotionController;

  final List<_Orb> _orbs = [];
  static const double _orbSize = 60;
  int _currentIndex = 0;
  int _currentPromotionStep = 0;
  bool _awaitingTap = false;
  GachaItemWithNewStatus? _resultToShow;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _focusController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _promotionController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateOrbPositions();
      _introController.forward().whenComplete(() {
        if (mounted) {
          setState(() {
            _awaitingTap = true;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _focusController.dispose();
    _promotionController.dispose();
    super.dispose();
  }

  void _calculateOrbPositions() {
    final size = MediaQuery.of(context).size;
    final count = widget.itemsWithStatus.length;
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count > 1 ? 3 : 1,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
    );
    final padding = EdgeInsets.symmetric(horizontal: 20, vertical: size.height / 4);

    for (int i = 0; i < count; i++) {
      final row = i ~/ gridDelegate.crossAxisCount;
      final col = i % gridDelegate.crossAxisCount;
      final itemWidth = (size.width - padding.horizontal) / gridDelegate.crossAxisCount;
      final x = padding.left + (col * itemWidth) + itemWidth / 2;
      final y = padding.top + (row * (itemWidth + gridDelegate.mainAxisSpacing)) + itemWidth / 2;

      _orbs.add(_Orb(
        itemWithStatus: widget.itemsWithStatus[i],
        isOpened: false,
        gridPosition: count > 1 ? Offset(x, y) : Offset(size.width / 2, size.height / 2),
      ));
    }
    if (mounted) setState(() {});
  }

  Future<void> _onTap() async {
    if (!_awaitingTap || _currentIndex >= widget.itemsWithStatus.length) return;
    
    setState(() {
      _awaitingTap = false;
      _currentPromotionStep = 0;
    });

    final currentItem = widget.itemsWithStatus[_currentIndex];

    await _focusController.forward();
    await Future.delayed(const Duration(milliseconds: 300));

    if (currentItem.didPromote) {
      for (int i = 0; i < currentItem.promotionPath.length - 1; i++) {
        if (!mounted) return;
        await _promotionController.forward(from: 0.0);
        setState(() {
          _currentPromotionStep++;
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _resultToShow = currentItem;
      });
    }
  }

  void _dismissResultAndProceed() {
    if (!mounted) return;

    setState(() {
      _orbs[_currentIndex].isOpened = true;
      _resultToShow = null;
    });

    _focusController.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        if (_currentIndex >= widget.itemsWithStatus.length) {
          _navigateToSummary();
        } else {
          _awaitingTap = true;
        }
      });
    });
  }

  void _navigateToSummary() {
    // Use a short delay to prevent the summary screen from appearing abruptly.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _awaitingTap ? _onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_introController, _focusController, _promotionController]),
                builder: (context, child) {
                  return Stack(
                    children: [
                      ...List.generate(_orbs.length, (index) {
                        final orb = _orbs[index];
                        final isFocused = index == _currentIndex;

                        final introAnimation = CurvedAnimation(parent: _introController, curve: Interval(index * 0.05, 0.5 + index * 0.05, curve: Curves.easeOut));
                        final focusAnimation = CurvedAnimation(parent: _focusController, curve: Curves.easeInOutCubic);

                        final centerPosition = Offset(screenSize.width / 2, screenSize.height / 2);

                        final position = isFocused ? Offset.lerp(orb.gridPosition, centerPosition, focusAnimation.value)! : orb.gridPosition;
                        final scale = isFocused ? 1.0 + (focusAnimation.value * 3.0) : 1.0;
                        final opacity = (index == _currentIndex || _focusController.value == 0.0) ? 1.0 : 1.0 - _focusController.value;

                        return Positioned(
                          left: position.dx - (_orbSize / 2),
                          top: position.dy - (_orbSize / 2),
                          child: Opacity(
                            opacity: introAnimation.value * opacity,
                            child: Transform.scale(
                              scale: introAnimation.value * scale,
                              child: _OrbWidget(
                                orb: orb,
                                promotionStep: isFocused ? _currentPromotionStep : 0,
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_promotionController.isAnimating)
                        Center(
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _promotionController, curve: Curves.easeIn)),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 1.0, end: 3.0).animate(_promotionController),
                              child: Container(
                                width: _orbSize * 4, height: _orbSize * 4,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.5)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (_awaitingTap && _currentIndex < widget.itemsWithStatus.length)
                Positioned(
                  bottom: 40, left: 0, right: 0,
                  child: Text(
                    widget.itemsWithStatus.length > 1 ? 'タップして次の玉を開封' : 'タップして開封',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 18, shadows: [Shadow(blurRadius: 8, color: Colors.black)]),
                  ),
                ),
              if (_resultToShow != null)
                GestureDetector(
                  onTap: _dismissResultAndProceed,
                  behavior: HitTestBehavior.opaque,
                  child: SingleGachaResultView(itemWithStatus: _resultToShow!),
                ),
              Positioned(
                top: 0, right: 10,
                child: TextButton(
                  onPressed: _navigateToSummary,
                  child: const Text('スキップ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Orb {
  final GachaItemWithNewStatus itemWithStatus;
  bool isOpened;
  final Offset gridPosition;

  _Orb({
    required this.itemWithStatus,
    required this.isOpened,
    required this.gridPosition,
  });
}

class _OrbWidget extends StatelessWidget {
  final _Orb orb;
  final int promotionStep;
  static const double _orbSize = 60;

  const _OrbWidget({required this.orb, required this.promotionStep});

  @override
  Widget build(BuildContext context) {
    final itemToShow = orb.itemWithStatus.promotionPath[promotionStep.clamp(0, orb.itemWithStatus.promotionPath.length - 1)];
    final color = itemToShow.rarity.color;
    
    if (orb.isOpened) {
      final finalColor = orb.itemWithStatus.finalItem.rarity.color;
      return Container(
        width: _orbSize, height: _orbSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle, 
          color: finalColor.withOpacity(0.3),
          border: Border.all(color: finalColor, width: 2)
        ),
      );
    }

    return Container(
      width: _orbSize, height: _orbSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.8), color],
          center: const Alignment(0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(color: color, blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Center(
        child: Container(
          width: _orbSize * 0.8,
          height: _orbSize * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.5), Colors.transparent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }
}