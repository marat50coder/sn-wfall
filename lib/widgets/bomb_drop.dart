import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../game/slot_model.dart';

/// Visual bomb "meteor" that streaks down from the sky into a specific cell.
class BombDrop extends StatefulWidget {
  const BombDrop({
    super.key,
    required this.tier,
    required this.targetIndex,
    required this.cellSize,
    required this.gridWidth,
    required this.gridHeight,
  });

  final PrizeTier tier;
  final int targetIndex;
  final double cellSize;
  final double gridWidth;
  final double gridHeight;

  @override
  State<BombDrop> createState() => _BombDropState();
}

class _BombDropState extends State<BombDrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _asset {
    switch (widget.tier) {
      case PrizeTier.mini:
        return 'assets/badges/mini.png';
      case PrizeTier.minor:
        return 'assets/badges/minor.png';
      case PrizeTier.major:
        return 'assets/badges/major.png';
      case PrizeTier.grand:
        return 'assets/badges/grand.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.targetIndex ~/ SlotConfig.rows;
    final y = widget.targetIndex % SlotConfig.rows;
    final targetX = r * widget.cellSize + widget.cellSize / 2 - widget.cellSize / 2;
    final targetY = y * widget.cellSize;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInCubic.transform(_c.value);
        // Move from top-center of the grid down to the target cell.
        final startY = -widget.cellSize * 1.2;
        final startX = widget.gridWidth / 2 - widget.cellSize / 2;
        final currentX = startX + (targetX - startX) * t;
        final currentY = startY + (targetY - startY) * t;
        final scale = 0.7 + 0.4 * t;
        return Stack(
          children: [
            // Trailing glow.
            Positioned(
              left: currentX + widget.cellSize * 0.1,
              top: currentY + widget.cellSize * 0.1,
              width: widget.cellSize * 0.8,
              height: widget.cellSize * 0.8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kAccentGold.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: currentX,
              top: currentY,
              width: widget.cellSize,
              height: widget.cellSize,
              child: Transform.scale(
                scale: scale,
                child: Image.asset(_asset, fit: BoxFit.contain),
              ),
            ),
          ],
        );
      },
    );
  }
}
