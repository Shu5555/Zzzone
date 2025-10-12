import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gacha_config.dart';
import '../models/gacha_item_with_new_status.dart';

class ThreeGachaAnimationScreen extends StatefulWidget {
  final List<GachaItemWithNewStatus> itemsWithStatus;
  final GachaConfig config;
  final int indexToFocus;
  final List<bool> openedOrbs;
  final bool isIntro;
  final VoidCallback onAnimationComplete;
  final VoidCallback onSkip;

  const ThreeGachaAnimationScreen({
    super.key,
    required this.itemsWithStatus,
    required this.config,
    required this.indexToFocus,
    required this.openedOrbs,
    required this.isIntro,
    required this.onAnimationComplete,
    required this.onSkip,
  });

  @override
  State<ThreeGachaAnimationScreen> createState() => _ThreeGachaAnimationScreenState();
}

class _ThreeGachaAnimationScreenState extends State<ThreeGachaAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _focusController;
  late AnimationController _promotionController;

  final List<_Orb> _orbs = [];
  static const double _orbSize = 60;
  bool _hasTapped = false;
  int _currentPromotionStep = 0;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _focusController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _promotionController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateOrbPositions();
      if (widget.isIntro) {
        _introController.forward();
      } else {
        _introController.value = 1.0;
        _onTap();
      }
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
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
    );
    final padding = const EdgeInsets.all(20);
    final itemWidth = (size.width - padding.horizontal) / gridDelegate.crossAxisCount;

    for (int i = 0; i < count; i++) {
      final row = i ~/ gridDelegate.crossAxisCount;
      final col = i % gridDelegate.crossAxisCount;
      final x = padding.left + (col * itemWidth) + itemWidth / 2;
      final y = padding.top + (row * itemWidth) + itemWidth / 2;

      _orbs.add(_Orb(
        itemWithStatus: widget.itemsWithStatus[i],
        isOpened: widget.openedOrbs[i],
        gridPosition: Offset(x, y),
      ));
    }
    if (mounted) setState(() {});
  }

  Future<void> _onTap() async {
    if (_hasTapped) return;
    setState(() {
      _hasTapped = true;
    });

    final currentItem = widget.itemsWithStatus[widget.indexToFocus];

    _focusController.forward();
    await Future.delayed(const Duration(milliseconds: 500));

    if (currentItem.didPromote) {
      for (int i = 0; i < currentItem.promotionPath.length - 1; i++) {
        if (!mounted) return;
        await _promotionController.forward(from: 0.0);
        setState(() {
          _currentPromotionStep++;
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      widget.onAnimationComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orbs.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: widget.isIntro ? _onTap : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_introController, _focusController, _promotionController]),
            builder: (context, child) {
              return Stack(
                children: [
                  ...List.generate(widget.itemsWithStatus.length, (index) {
                    final orb = _orbs[index];
                    final isFocused = index == widget.indexToFocus;

                    final introAnimation = CurvedAnimation(parent: _introController, curve: Interval(index * 0.05, 0.5 + index * 0.05, curve: Curves.easeOut));
                    final focusAnimation = CurvedAnimation(parent: _focusController, curve: Curves.easeInOutCubic);

                    final screenSize = MediaQuery.of(context).size;
                    final centerPosition = Offset(screenSize.width / 2, screenSize.height / 2);

                    final position = isFocused ? Offset.lerp(orb.gridPosition, centerPosition, focusAnimation.value)! : orb.gridPosition;
                    final scale = isFocused ? 1.0 + (focusAnimation.value * 3.0) : 1.0;
                    final opacity = isFocused ? 1.0 : 1.0 - focusAnimation.value;

                    return Positioned(
                      left: position.dx - (_orbSize / 2),
                      top: position.dy - (_orbSize / 2),
                      child: Opacity(
                        opacity: introAnimation.value * opacity,
                        child: Transform.scale(
                          scale: introAnimation.value * scale,
                          child: _OrbWidget(
                            orb: orb,
                            promotionStep: _currentPromotionStep,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_introController.isCompleted && !_hasTapped && widget.isIntro)
                    const Positioned(
                      bottom: 40, left: 0, right: 0,
                      child: Text('タップして開封', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18)),
                    ),
                  if (widget.itemsWithStatus[widget.indexToFocus].didPromote && _promotionController.isAnimating)
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
                  Positioned(
                    top: 0, right: 10,
                    child: TextButton(
                      onPressed: widget.onSkip,
                      child: const Text('スキップ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Orb {
  final GachaItemWithNewStatus itemWithStatus;
  final bool isOpened;
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
    final promotionPath = orb.itemWithStatus.promotionPath;
    final itemToShow = promotionPath[promotionStep.clamp(0, promotionPath.length - 1)];
    final color = itemToShow.rarity.color;
    final isCommon = itemToShow.rarity.name == 'コモン';

    if (orb.isOpened) {
      return Container(
        width: _orbSize, height: _orbSize,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[850], border: Border.all(color: Colors.grey[700]!, width: 2)),
      );
    }

    if (isCommon) {
      return Container(
        width: _orbSize, height: _orbSize,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFBDBDBD)),
      );
    }

    return Container(
      width: _orbSize, height: _orbSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 25, spreadRadius: 5)],
      ),
    );
  }
}
