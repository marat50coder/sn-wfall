import 'package:flutter/material.dart';

import 'snowfall_theme.dart';

// ============================================================
//  Shared buttons for the gray surfaces
// ============================================================
//  Deliberately different in silhouette from the game's gold
//  pills — the gray screens use frosted ice-blue capsules with
//  a bevelled stroke so the two surfaces never look template-y
//  side by side (see gray_part_pitfalls.md §12, §13).
// ============================================================

enum _ButtonFlavour { ice, ghost }

class SnowfallPillButton extends StatefulWidget {
  const SnowfallPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final bool compact;

  @override
  State<SnowfallPillButton> createState() => _SnowfallPillButtonState();
}

class _SnowfallPillButtonState extends State<SnowfallPillButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return _flavouredButton(
      flavour: _ButtonFlavour.ice,
      label: widget.label,
      onTap: widget.onTap,
      width: widget.width,
      compact: widget.compact,
      scale: _scale,
      onScale: (double v) => setState(() => _scale = v),
    );
  }
}

class SnowfallGhostButton extends StatefulWidget {
  const SnowfallGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final bool compact;

  @override
  State<SnowfallGhostButton> createState() => _SnowfallGhostButtonState();
}

class _SnowfallGhostButtonState extends State<SnowfallGhostButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return _flavouredButton(
      flavour: _ButtonFlavour.ghost,
      label: widget.label,
      onTap: widget.onTap,
      width: widget.width,
      compact: widget.compact,
      scale: _scale,
      onScale: (double v) => setState(() => _scale = v),
    );
  }
}

Widget _flavouredButton({
  required _ButtonFlavour flavour,
  required String label,
  required VoidCallback onTap,
  required double? width,
  required bool compact,
  required double scale,
  required ValueChanged<double> onScale,
}) {
  final List<Color> gradient = flavour == _ButtonFlavour.ice
      ? const <Color>[Color(0xFF9CD4FF), Color(0xFF2E78C9), Color(0xFF123F7A)]
      : const <Color>[Color(0xFF1B2E52), Color(0xFF0E1E3B)];
  final Color border = flavour == _ButtonFlavour.ice
      ? SnowfallTheme.crystal
      : SnowfallTheme.crystal.withValues(alpha: 0.6);

  return GestureDetector(
    onTapDown: (_) => onScale(0.95),
    onTapCancel: () => onScale(1.0),
    onTapUp: (_) {
      onScale(1.0);
      onTap();
    },
    child: AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Container(
        width: width,
        height: compact ? 48 : 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: SnowfallTheme.crystal.withValues(alpha: 0.4),
              offset: const Offset(0, 4),
              blurRadius: 14,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                height: 1.0,
                shadows: const <Shadow>[
                  Shadow(
                    color: Color(0x99000000),
                    offset: Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
