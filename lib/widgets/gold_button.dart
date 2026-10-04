import 'package:flutter/material.dart';

import '../app_theme.dart';

enum GoldButtonVariant { gold, blue }

class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.variant = GoldButtonVariant.gold,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final GoldButtonVariant variant;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGold = widget.variant == GoldButtonVariant.gold;
    final List<Color> fill = isGold
        ? const [Color(0xFFFFE28C), Color(0xFFE0A93A), Color(0xFF8A5A0F)]
        : const [Color(0xFF6FC5FF), Color(0xFF2E7BE0), Color(0xFF0F2B66)];
    final Color border = isGold ? const Color(0xFFFFF4B8) : const Color(0xFFB8E1FF);
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final scale = 1.0 - (_ctrl.value * 0.04);
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: fill,
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(color: border, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isGold ? kAccentGold : kAccentIce).withValues(alpha: 0.55),
                blurRadius: 12,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Color(0x88000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 26, shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 4),
                ]),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
