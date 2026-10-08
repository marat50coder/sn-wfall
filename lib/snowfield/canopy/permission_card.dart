import 'package:flutter/material.dart';

import '../../shell/snowfall_buttons.dart';
import '../dossier/client_dossier.dart';
import '../circuit/aurora_vault.dart';
import '../circuit/push_dispatch.dart';
import 'content_screen.dart';

// ============================================================
//  PermissionCard — push opt-in promo
// ============================================================
//  Uses the game's existing aurora_invite_portrait.webp
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
  final PushDispatch relay;
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
        ? 'assets/Snowfall_Odyssey_additional_assets/aurora_invite_landscape.webp'
        : 'assets/Snowfall_Odyssey_additional_assets/aurora_invite_portrait.webp';

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
            // In landscape (aurora_invite_landscape) place both
            // buttons on Skip's row, shrunk by 15% per side (→ 70% of
            // their original width). Portrait keeps the stacked layout.
            child: landscape
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      SnowfallPillButton(
                        label: 'Accept',
                        width: size.width * 0.34 * 0.70,
                        compact: true,
                        onTap: _accept,
                      ),
                      SizedBox(width: size.width * 0.04),
                      SnowfallGhostButton(
                        label: 'Skip',
                        width: size.width * 0.34 * 0.70,
                        compact: true,
                        onTap: _skip,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SnowfallPillButton(
                        label: 'Accept',
                        width: size.width * 0.72,
                        compact: false,
                        onTap: _accept,
                      ),
                      const SizedBox(height: 14),
                      SnowfallGhostButton(
                        label: 'Skip',
                        width: size.width * 0.72,
                        compact: false,
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
