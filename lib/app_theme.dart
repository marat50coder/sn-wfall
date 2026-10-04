import 'package:flutter/material.dart';

const Color kDeepBlue = Color(0xFF0B1E3F);
const Color kNightBlue = Color(0xFF061132);
const Color kAccentGold = Color(0xFFF5C349);
const Color kAccentGoldDark = Color(0xFF8A5A0F);
const Color kAccentIce = Color(0xFF6FC5FF);
const Color kPanelDark = Color(0xE60A1330);
const Color kPanelBorder = Color(0xFF3E76B8);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kNightBlue,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.dark(
      primary: kAccentGold,
      secondary: kAccentIce,
      surface: kDeepBlue,
    ),
  );
}
