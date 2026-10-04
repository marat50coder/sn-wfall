import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../game/currency.dart';
import '../game/slot_model.dart';

class WheelBonusScreen extends StatefulWidget {
  const WheelBonusScreen({
    super.key,
    required this.theme,
    required this.bet,
  });

  final WheelTheme theme;
  final double bet;

  @override
  State<WheelBonusScreen> createState() => _WheelBonusScreenState();
}

class _WheelBonusScreenState extends State<WheelBonusScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _introCtrl;
  late final AnimationController _winPulseCtrl;
  final math.Random _rng = math.Random();

  double _finalAngle = 0.0;
  bool _spinning = false;
  bool _finished = false;
  int _winningIndex = -1;

  double _payout = 0.0;
  String _payoutLabel = '';

  // Matches the 12 divisions of the wheel artwork (12 alternating colour
  // wedges). Every wedge carries its own multiplier, distributed so low
  // rewards are common and jackpot values are rare.
  static const int _segments = 12;

  late final List<int> _multipliers;
  late final List<String> _labels;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _winPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 12 payouts per wheel, spread around the ring so neighbouring sectors
    // alternate between small/medium/large rewards for visual variety.
    switch (widget.theme) {
      case WheelTheme.fire:
        _multipliers = const [2, 8, 3, 15, 5, 50, 3, 10, 5, 25, 2, 100];
        break;
      case WheelTheme.ice:
        _multipliers = const [1, 4, 2, 10, 3, 20, 2, 6, 3, 15, 1, 50];
        break;
      case WheelTheme.sweet:
        _multipliers = const [3, 8, 4, 18, 5, 30, 4, 12, 6, 25, 3, 75];
        break;
      case WheelTheme.zeus:
        _multipliers = const [5, 15, 8, 30, 10, 60, 8, 20, 12, 50, 5, 150];
        break;
    }
    _labels = _multipliers.map((m) => 'x$m').toList();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _introCtrl.dispose();
    _winPulseCtrl.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_spinning || _finished) return;
    setState(() => _spinning = true);
    final segIndex = _rng.nextInt(_segments);
    final anglePerSeg = 2 * math.pi / _segments;
    // Negative rotation brings segment `segIndex` (drawn clockwise from the
    // top) exactly under the pointer. Full turns keep the motion a spin.
    final target = -segIndex * anglePerSeg;
    final totalTurns = 2 + _rng.nextDouble();
    final endAngle = target - totalTurns * 2 * math.pi;

    setState(() {
      _finalAngle = endAngle;
      _winningIndex = segIndex;
    });
    _spinCtrl.reset();
    _spinCtrl.forward().whenComplete(() {
      // Credit whatever sector is actually under the pointer, not a value
      // chosen separately from the art. Same formula as the label positions.
      final landed = _indexUnderPointer(_finalAngle);
      final mult = _multipliers[landed].toDouble();
      setState(() {
        _winningIndex = landed;
        _payout = mult * widget.bet;
        _payoutLabel = _labels[landed];
        _finished = true;
        _spinning = false;
      });
      _winPulseCtrl.repeat(reverse: true);
    });
  }

  /// Sector whose centre sits under the top pointer after [rotation].
  ///
  /// Label i is drawn at angle `-pi/2 + i * seg` (0 = straight up). Flutter's
  /// [Transform.rotate] is clockwise for a positive angle, which matches that
  /// placement, so the inverse is `i = -rotation / seg`.
  int _indexUnderPointer(double rotation) {
    final seg = 2 * math.pi / _segments;
    var i = (-rotation / seg).round() % _segments;
    if (i < 0) i += _segments;
    return i;
  }

  String get _bgAsset {
    switch (widget.theme) {
      case WheelTheme.fire:
      case WheelTheme.zeus:
        return 'assets/Snowfall_Odyssey_gameplay_assets/bg3_asset.webp';
      case WheelTheme.ice:
      case WheelTheme.sweet:
        return 'assets/Snowfall_Odyssey_gameplay_assets/bg2_asset.webp';
    }
  }

  String get _wheelAsset {
    switch (widget.theme) {
      case WheelTheme.fire:
        return 'assets/wheels/wheel_fire.png';
      case WheelTheme.ice:
        return 'assets/wheels/wheel_ice.png';
      case WheelTheme.sweet:
        return 'assets/wheels/wheel_sweet.png';
      case WheelTheme.zeus:
        return 'assets/wheels/wheel_zeus.png';
    }
  }

  String get _characterAsset {
    switch (widget.theme) {
      case WheelTheme.fire:
        return 'assets/characters/joker.png';
      case WheelTheme.ice:
        return 'assets/characters/winter_man.png';
      case WheelTheme.sweet:
        return 'assets/characters/lollipop.png';
      case WheelTheme.zeus:
        return 'assets/characters/zeus.png';
    }
  }

  String get _title {
    switch (widget.theme) {
      case WheelTheme.fire:
        return 'JOKER FIRE WHEEL';
      case WheelTheme.ice:
        return 'FROSTBITE WHEEL';
      case WheelTheme.sweet:
        return 'SWEET FORTUNE WHEEL';
      case WheelTheme.zeus:
        return 'ZEUS THUNDER WHEEL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNightBlue,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_bgAsset, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              return Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildCharacter(c.maxHeight),
                        _buildWheel(c),
                      ],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              );
            }),
          ),
          if (_finished) _buildResultOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _iconBtn(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).pop(_payout),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF8A5A0F), Color(0xFFF5C349), Color(0xFF8A5A0F)],
              ),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: Text(
              _title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 14,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kAccentGold.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildCharacter(double maxH) {
    return AnimatedBuilder(
      animation: _introCtrl,
      builder: (context, child) {
        final v = Curves.easeOutBack.transform(_introCtrl.value.clamp(0.0, 1.0));
        return Positioned(
          left: 4 + (1 - v) * -140,
          bottom: 8,
          width: 150,
          height: maxH * 0.78,
          child: Opacity(opacity: _introCtrl.value, child: child),
        );
      },
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Image.asset(_characterAsset,
            fit: BoxFit.contain, alignment: Alignment.bottomCenter),
      ),
    );
  }

  Widget _buildWheel(BoxConstraints c) {
    // Reserve space for the pointer above and character on the left.
    final maxSize = math.min(c.maxWidth * 0.90, c.maxHeight * 0.78);
    final size = maxSize;
    return SizedBox(
      width: size,
      height: size + 24, // Room for the top pointer.
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Halo behind the wheel.
          Positioned(
            top: 24,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kAccentGold.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Rotating wheel: background asset + segment labels drawn on top
          // via CustomPaint so numbers sit exactly inside their sector.
          Positioned(
            top: 24,
            child: AnimatedBuilder(
              animation: _spinCtrl,
              builder: (context, _) {
                final v = Curves.easeOutCubic.transform(_spinCtrl.value);
                final angle = _finalAngle * v;
                return Transform.rotate(
                  angle: angle,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(_wheelAsset, width: size, height: size),
                      // Highlight the landed segment once the wheel stops.
                      if (_finished && _winningIndex >= 0)
                        _SegmentHighlight(
                          segIndex: _winningIndex,
                          segCount: _segments,
                          size: size,
                          pulse: _winPulseCtrl,
                        ),
                      // Painted labels inside each sector.
                      SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(
                          painter: _WheelLabelsPainter(
                            labels: _labels,
                            segCount: _segments,
                            wheelSize: size,
                            winningIndex: _finished ? _winningIndex : -1,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Pointer stays on the outer rim and marks the winning sector.
          Positioned(
            top: 0,
            child: _Pointer(),
          ),
          // Center CTA (SPIN button), only when idle.
          if (!_spinning && !_finished)
            Positioned(
              top: 24 + size / 2 - size * 0.13,
              child: GestureDetector(
                onTap: _spinWheel,
                child: Container(
                  width: size * 0.26,
                  height: size * 0.26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFE28C),
                        Color(0xFFE0A93A),
                        Color(0xFF8A5A0F),
                      ],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: kAccentGold.withValues(alpha: 0.7),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'SPIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 18,
                        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay() {
    return Positioned.fill(
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFF5C349), Color(0xFF8A5A0F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: kAccentGold.withValues(alpha: 0.7),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'YOU WON',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 3,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _payoutLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
              Text(
                formatFans(_payout),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_payout),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDeepBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
                child: const Text('COLLECT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: kAccentGold, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _bottomInfo('BET · $kCurrencyName',
              formatFans(widget.bet, withUnit: false)),
          _bottomInfo('WIN · $kCurrencyName',
              formatFans(_payout, withUnit: false)),
        ],
      ),
    );
  }

  Widget _bottomInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            )),
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            )),
      ],
    );
  }
}

/// Paints the multiplier label into the middle of each wheel sector, so the
/// text stays inside the ring instead of drifting outside.
class _WheelLabelsPainter extends CustomPainter {
  _WheelLabelsPainter({
    required this.labels,
    required this.segCount,
    required this.wheelSize,
    required this.winningIndex,
  });

  final List<String> labels;
  final int segCount;
  final double wheelSize;
  final int winningIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Coloured wedges sit roughly between 30% and 60% of the wheel radius.
    // 0.22 of the full size is the middle of that band, clear of both the
    // centre button and the gold frame.
    // Middle of the coloured wedge: clear of the centre button and of the
    // gold rim.
    final radius = wheelSize * 0.22;
    final anglePerSeg = 2 * math.pi / segCount;

    for (var i = 0; i < segCount; i++) {
      // Index 0 is the wedge under the top pointer.
      final theta = -math.pi / 2 + anglePerSeg * i;
      final pos = center + Offset(math.cos(theta), math.sin(theta)) * radius;

      final isWin = i == winningIndex;
      final fontSize = wheelSize * (isWin ? 0.048 : 0.034);
      final style = TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        letterSpacing: 0.1,
        height: 1.0,
      );
      final fill = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: style.copyWith(color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      final stroke = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: style.copyWith(color: const Color(0xFF1A0A00)),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      // Keep every reward upright and centred in its own wedge. Radial text
      // used to lean into the next cell, so the pointer looked like it had
      // landed on a different multiplier than the one that was paid.
      final origin = Offset(-fill.width / 2, -fill.height / 2);
      const outline = 1.3;
      for (final o in const [
        Offset(-outline, 0),
        Offset(outline, 0),
        Offset(0, -outline),
        Offset(0, outline),
        Offset(-outline, -outline),
        Offset(outline, -outline),
        Offset(-outline, outline),
        Offset(outline, outline),
      ]) {
        stroke.paint(canvas, origin + o);
      }
      fill.paint(canvas, origin);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WheelLabelsPainter oldDelegate) =>
      oldDelegate.winningIndex != winningIndex ||
      oldDelegate.wheelSize != wheelSize;
}

/// Overlays a glowing wedge highlight on the winning segment.
class _SegmentHighlight extends StatelessWidget {
  const _SegmentHighlight({
    required this.segIndex,
    required this.segCount,
    required this.size,
    required this.pulse,
  });

  final int segIndex;
  final int segCount;
  final double size;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SegmentHighlightPainter(
              segIndex: segIndex,
              segCount: segCount,
              wheelSize: size,
              t: Curves.easeInOut.transform(pulse.value),
            ),
          ),
        );
      },
    );
  }
}

class _SegmentHighlightPainter extends CustomPainter {
  _SegmentHighlightPainter({
    required this.segIndex,
    required this.segCount,
    required this.wheelSize,
    required this.t,
  });
  final int segIndex;
  final int segCount;
  final double wheelSize;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Stay inside the coloured wedges: outside the centre gem, inside the
    // gold frame.
    final rOuter = wheelSize * 0.30;
    final rInner = wheelSize * 0.15;
    final anglePerSeg = 2 * math.pi / segCount;
    final theta = -math.pi / 2 + anglePerSeg * segIndex;
    final start = theta - anglePerSeg / 2;

    // Build the wedge path.
    final path = Path();
    path.moveTo(center.dx + rInner * math.cos(start),
        center.dy + rInner * math.sin(start));
    path.lineTo(center.dx + rOuter * math.cos(start),
        center.dy + rOuter * math.sin(start));
    path.arcTo(Rect.fromCircle(center: center, radius: rOuter), start,
        anglePerSeg, false);
    path.lineTo(center.dx + rInner * math.cos(start + anglePerSeg),
        center.dy + rInner * math.sin(start + anglePerSeg));
    path.arcTo(Rect.fromCircle(center: center, radius: rInner),
        start + anglePerSeg, -anglePerSeg, false);
    path.close();

    // Bright fill.
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.35 + 0.25 * t);
    canvas.drawPath(path, fill);

    // Gold border around the wedge.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 + 3 * t
      ..color = const Color(0xFFFFE28C).withValues(alpha: 0.9);
    canvas.drawPath(path, border);

    // Soft outer glow.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 4 * t)
      ..color = const Color(0xFFFFE28C).withValues(alpha: 0.45 + 0.35 * t);
    canvas.drawPath(path, glow);
  }

  @override
  bool shouldRepaint(covariant _SegmentHighlightPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.segIndex != segIndex;
}

class _Pointer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 46,
      child: CustomPaint(painter: _PointerPainter()),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE28C), Color(0xFFE0A93A), Color(0xFF8A5A0F)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(path, border);
    // Small glow.
    final glow = Paint()
      ..color = kAccentGold.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
