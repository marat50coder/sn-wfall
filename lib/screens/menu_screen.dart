import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../game/currency.dart';
import '../gate/gate_core.dart';
import '../gate/sealed_ids.dart';
import '../widgets/gold_button.dart';
import 'game_screen.dart';
import 'web_screen.dart';

/// Fetch a sealed URL from the native library. Returns `''` if the .so is
/// missing or the slot is empty — the caller falls back to a "coming soon"
/// snackbar so the button never looks broken.
String _sealedUrl(SealedId id) {
  final core = GateCore.open();
  if (core == null) return '';
  return core.unsealString(id);
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    // Vertical only for gameplay/menu.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _openWeb(String title, String url) {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: kDeepBlue,
          content: Text(
            '$title will be available soon.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebScreen(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNightBlue,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Snowfall_Odyssey_additional_assets/Vertical_Loading_Screen.webp',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x66000000),
                  Color(0xEE061132),
                ],
                stops: [0.35, 0.6, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  GoldButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  GoldButton(
                    label: 'PRIVACY POLICY',
                    icon: Icons.shield_moon_outlined,
                    variant: GoldButtonVariant.blue,
                    onTap: () => _openWeb(
                        'Privacy Policy', _sealedUrl(SealedId.privacyUrl)),
                  ),
                  const SizedBox(height: 14),
                  GoldButton(
                    label: 'SUPPORT',
                    icon: Icons.support_agent_rounded,
                    variant: GoldButtonVariant.blue,
                    onTap: () => _openWeb(
                        'Support', _sealedUrl(SealedId.supportUrl)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border.all(
                          color: kAccentGold.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      kCurrencyDisclaimer,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
