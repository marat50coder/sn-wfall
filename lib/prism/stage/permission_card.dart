import 'package:flutter/material.dart';

import '../../shell/snowfall_buttons.dart';
import '../config/client_dossier.dart';
import '../wire/aurora_vault.dart';
import '../wire/signal_relay.dart';
import 'content_screen.dart';

// ============================================================
//  PermissionCard — push opt-in promo
// ============================================================
//  Uses the game's existing Vertical_Notifications_Screen.webp
//  as the hero art — the design matches the Snowfall palette
//  and already carries bonus iconography. Accept / Skip are
//  gradient pills (same family as the game buttons, see
//  gray_part_pitfalls.md §12 for the "no low-contrast text
//  Skip" rule).
// ============================================================

class PermissionCard extends StatefulWidget {
  const PermissionCard({
    super.key,
    required this.vault,
    required this.relay,
    required this.target,
  });

  final AuroraVault vault;
  final SignalRelay relay;
  final String target;

  @override
  State<PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<PermissionCard> {
  bool _running = false;

  Future<void> _accept() async {
    if (_running) return;
    setState(() => _running = true);
    final bool granted = await widget.relay.requestPushPermission();
    if (!granted) {
      await widget.vault.stashPushSnooze(_snoozeUntil());
    }
    if (mounted) _forward();
  }

  Future<void> _skip() async {
    if (_running) return;
    setState(() => _running = true);
    await widget.vault.stashPushSnooze(_snoozeUntil());
    if (mounted) _forward();
  }

  int _snoozeUntil() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      ClientDossier.permissionSnoozeSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ContentScreen(
          url: widget.target,
          vault: widget.vault,
          relay: widget.relay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? 'assets/Snowfall_Odyssey_additional_assets/Horizontal_Notifications_Screen.webp'
        : 'assets/Snowfall_Odyssey_additional_assets/Vertical_Notifications_Screen.webp';

    return Scaffold(
      backgroundColor: const Color(0xFF061132),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0xAA000000)],
              ),
            ),
          ),
          Positioned(
            left: size.width * 0.08,
            right: size.width * 0.08,
            bottom: size.height * (landscape ? 0.07 : 0.08),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SnowfallPillButton(
                  label: 'Accept',
                  width: landscape ? size.width * 0.34 : size.width * 0.72,
                  compact: landscape,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 10 : 14),
                SnowfallGhostButton(
                  label: 'Skip',
                  width: landscape ? size.width * 0.34 : size.width * 0.72,
                  compact: landscape,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
