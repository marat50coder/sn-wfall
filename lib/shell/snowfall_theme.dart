import 'package:flutter/material.dart';

/// Palette + text helpers for the gray surfaces (loading screen,
/// permission card, offline screen). The white game owns its own
/// theme at `lib/app_theme.dart`; they intentionally diverge in
/// hex to keep the fingerprint distinct.
class SnowfallTheme {
  SnowfallTheme._();

  static const Color deepIce = Color(0xFF061132);
  static const Color midIce = Color(0xFF0B1E3F);
  static const Color crystal = Color(0xFF9CD4FF);
  static const Color crystalDeep = Color(0xFF2E78C9);
  static const Color gold = Color(0xFFF5C349);
  static const Color goldDeep = Color(0xFF8A5A0F);

  static ThemeData build() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: crystal,
      primary: crystal,
      surface: deepIce,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: deepIce,
      fontFamily: 'Roboto',
    );
  }

  static TextStyle titleStyle({double size = 28, Color color = Colors.white}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: 0.6,
      height: 1.0,
      shadows: const <Shadow>[
        Shadow(color: Color(0xCC000000), offset: Offset(0, 2), blurRadius: 6),
      ],
    );
  }

  static TextStyle bodyStyle({double size = 15, Color color = Colors.white}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color.withValues(alpha: 0.92),
      letterSpacing: 0.3,
      height: 1.3,
      shadows: const <Shadow>[
        Shadow(color: Color(0x88000000), blurRadius: 3),
      ],
    );
  }
}
