import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../snowfield/trail/step_verdict.dart';
import '../snowfield/snowfield_director.dart';
import '../snowfield/canopy/content_screen.dart';
import '../snowfield/canopy/offline_screen.dart';
import '../snowfield/canopy/permission_card.dart';
import '../snowfield/circuit/aurora_vault.dart';
import '../snowfield/circuit/push_dispatch.dart';
import '../screens/menu_screen.dart';
import '../shell/snowfall_theme.dart';

// ============================================================
//  BootCanvas — the single startup surface
// ============================================================
//  One job: show the vertical/horizontal Snowfall loading art
//  with a progress bar while `SnowfieldDirector.plan` resolves, then
//  switch to exactly one destination. All routing logic lives in
//  the director; this file only owns the `switch (step)`.
// ============================================================

class BootCanvas extends StatefulWidget {
  const BootCanvas({
    super.key,
    required this.director,
    required this.vault,
    required this.relay,
  });

  final SnowfieldDirector director;
  final AuroraVault vault;
  final PushDispatch relay;

  @override
  State<BootCanvas> createState() => _BootCanvasState();
}

class _BootCanvasState extends State<BootCanvas>
    with SingleTickerProviderStateMixin {
  static const Duration _dotsPeriod = Duration(milliseconds: 1200);
  static const String _verticalArt =
      'assets/Snowfall_Odyssey_additional_assets/winter_warmup_portrait.webp';
  static const String _horizontalArt =
      'assets/Snowfall_Odyssey_additional_assets/winter_warmup_landscape.webp';

  double _progress = 0.04;
  bool _landed = false;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(vsync: this, duration: _dotsPeriod)..repeat();
    _drive();
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  Future<void> _drive() async {
    final StepVerdict step =
        await widget.director.plan(onTick: _liftProgress);
    if (!mounted || _landed) return;
    _landed = true;

    // Short settle so the progress bar visibly reaches 100%.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    final Widget next = switch (step) {
      GridStep() => await _toGrid(),
      SurfaceStep(url: final String url) => _toSurface(url),
      OutageStep() => _toOutage(),
    };
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => next),
    );
  }

  Future<Widget> _toGrid() async {
    // The game runs portrait-only.
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return const MenuScreen();
  }

  Widget _toSurface(String url) {
    if (widget.vault.shouldOfferPush) {
      return PermissionCard(
        vault: widget.vault,
        relay: widget.relay,
        target: url,
      );
    }
    return ContentScreen(
      url: url,
      vault: widget.vault,
      relay: widget.relay,
    );
  }

  Widget _toOutage() {
    return OfflineScreen(
      onRetryBuild: (_) => BootCanvas(
        director: widget.director,
        vault: widget.vault,
        relay: widget.relay,
      ),
    );
  }

  void _liftProgress(double value) {
    if (mounted) setState(() => _progress = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape ? _horizontalArt : _verticalArt;

    return Scaffold(
      backgroundColor: SnowfallTheme.deepIce,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0xBB000000)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _dots,
                    builder: (BuildContext context, _) {
                      final int n = (_dots.value * 4).floor() % 4;
                      return Text(
                        'Loading${'.' * n}',
                        style: SnowfallTheme.titleStyle(size: 22),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ProgressBand(value: _progress),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBand extends StatelessWidget {
  const _ProgressBand({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return Container(
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0x66000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SnowfallTheme.crystal, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: SnowfallTheme.crystal.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              width: c.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF9CD4FF),
                    Color(0xFF2E78C9),
                    Color(0xFFF5C349),
                  ],
                  stops: <double>[0.0, 0.65, 1.0],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }
}
