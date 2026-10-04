import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'slot_model.dart';

/// A single grid cell rendered inside a fixed square. The symbol image is
/// wrapped in Center + FractionallySizedBox so it stays perfectly centred
/// no matter how tall or narrow the sprite is — this fixes the visual "the
/// leftmost/rightmost reel drifts inward" issue.
class CellWidget extends StatelessWidget {
  const CellWidget({
    super.key,
    required this.cell,
    required this.size,
    this.matched = false,
    this.dimmed = false,
    this.scatterHighlight = false,
  });

  final Cell cell;
  final double size;
  final bool matched;
  final bool dimmed;

  /// When true, the cell renders a stronger, coloured pulse used to announce
  /// that scatters are about to trigger the bonus wheel.
  final bool scatterHighlight;

  @override
  Widget build(BuildContext context) {
    final assetPath = cell.prizeTier != null
        ? _bombAssetForTier(cell.prizeTier!)
        : cell.symbol.assetPath;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Faint background tile behind the symbol.
          Container(
            margin: EdgeInsets.all(size * 0.04),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.14),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: dimmed ? 0.02 : 0.06),
                  Colors.white.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          // Symbol image — always centred, filling ~82% of the cell so
          // regardless of the sprite's own aspect ratio it stays visually
          // centred inside the cell box.
          Center(
            child: SizedBox(
              width: size * 0.82,
              height: size * 0.82,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                gaplessPlayback: true,
              ),
            ),
          ),
          if (matched) _MatchGlow(size: size),
          if (scatterHighlight) _ScatterAnnouncement(size: size),
          if (cell.prizeTier != null) _BombPulse(size: size),
        ],
      ),
    );
  }

  static String _bombAssetForTier(PrizeTier t) {
    switch (t) {
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
}

class _MatchGlow extends StatefulWidget {
  const _MatchGlow({required this.size});
  final double size;

  @override
  State<_MatchGlow> createState() => _MatchGlowState();
}

class _MatchGlowState extends State<_MatchGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          margin: EdgeInsets.all(widget.size * 0.05),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.size * 0.14),
            border: Border.all(
              color: kAccentGold.withValues(alpha: 0.6 + 0.4 * t),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: kAccentGold.withValues(alpha: 0.4 + 0.4 * t),
                blurRadius: 14 + 10 * t,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScatterAnnouncement extends StatefulWidget {
  const _ScatterAnnouncement({required this.size});
  final double size;

  @override
  State<_ScatterAnnouncement> createState() => _ScatterAnnouncementState();
}

class _ScatterAnnouncementState extends State<_ScatterAnnouncement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final scale = 1.0 + 0.12 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            margin: EdgeInsets.all(widget.size * 0.04),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.16),
              border: Border.all(
                color: const Color(0xFFFFFFFF).withValues(alpha: 0.9),
                width: 4,
              ),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFEC94).withValues(alpha: 0.35 + 0.35 * t),
                  const Color(0xFFFFB33A).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC94A)
                      .withValues(alpha: 0.55 + 0.35 * t),
                  blurRadius: 22 + 16 * t,
                  spreadRadius: 2 + 2 * t,
                ),
                BoxShadow(
                  color: const Color(0xFFFF6B18)
                      .withValues(alpha: 0.35 + 0.25 * t),
                  blurRadius: 30 + 14 * t,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BombPulse extends StatefulWidget {
  const _BombPulse({required this.size});
  final double size;

  @override
  State<_BombPulse> createState() => _BombPulseState();
}

class _BombPulseState extends State<_BombPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final scale = 1.0 + 0.05 * math.sin(t * 2 * math.pi);
        return Transform.scale(scale: scale, child: const SizedBox.expand());
      },
    );
  }
}
