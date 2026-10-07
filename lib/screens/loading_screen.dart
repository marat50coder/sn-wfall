import 'dart:async';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../gate/gate_service.dart';
import '../gate/gray_screen.dart';
import 'menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnim;
  late AnimationController _dotsController;
  Timer? _launchTimer;
  Future<GateResult>? _gateFuture;

  @override
  void initState() {
    super.initState();

    // Progress: eases up to 0.9 slowly, then a final short animation snaps to 1.0
    // right before we launch to the menu screen.
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 0.9)
        .animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic));

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _progressController.forward();

    // Start the gate decision in parallel with the splash animation.
    // The .so is loaded lazily, decryption + POST happen on an isolate so
    // we don't block the 60 fps progress bar.
    _gateFuture = _runGate();

    // Right before launch, fill to 100% then navigate.
    _launchTimer = Timer(const Duration(milliseconds: 4200), _finalizeAndLaunch);
  }

  /// Resolve the gate in a short-lived helper so the loading-screen
  /// state doesn't accumulate network objects.
  Future<GateResult> _runGate() async {
    try {
      return const GateService().decide(appVersion: '1.0.0');
    } catch (_) {
      return GateResult.stayWhite();
    }
  }

  Future<void> _finalizeAndLaunch() async {
    // Final snap: 0.9 -> 1.0 over 400ms right before launch.
    final finalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final finalAnim = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: finalCtrl, curve: Curves.easeInOut));
    setState(() {
      _progressAnim = finalAnim;
    });
    await finalCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));

    // Wait for the gate decision (bounded by the gate's own HTTP timeout).
    final gate = await (_gateFuture ?? Future.value(GateResult.stayWhite()));
    if (!mounted) return;

    Widget next;
    if (gate.isGray) {
      next = GrayScreen(result: gate);
    } else {
      next = const MenuScreen();
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _launchTimer?.cancel();
    _progressController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNightBlue,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxHeight >= constraints.maxWidth;
          final image = isPortrait
              ? 'assets/Snowfall_Odyssey_additional_assets/Vertical_Loading_Screen.webp'
              : 'assets/Snowfall_Odyssey_additional_assets/Horizontal_Loading_Screen.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(image, fit: BoxFit.cover),
              // Bottom overlay with progress bar and Loading text.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomOverlay(isPortrait),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomOverlay(bool isPortrait) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        isPortrait ? 48 : 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB00A1330), Color(0xF0061132)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLoadingText(),
          const SizedBox(height: 14),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildLoadingText() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        final t = _dotsController.value;
        final dotCount = ((t * 4).floor()) % 4; // 0..3
        final dots = '.' * dotCount;
        return Text(
          'Loading$dots',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
            color: Colors.white,
            shadows: [
              Shadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, _) {
        final v = _progressAnim.value.clamp(0.0, 1.0);
        return LayoutBuilder(builder: (context, c) {
          const height = 18.0;
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: kAccentGold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: kAccentGold.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height / 2),
              child: Stack(
                children: [
                  // Fill from left to right
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: v,
                    heightFactor: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF61E3FF),
                            Color(0xFF39A9FF),
                            Color(0xFFF5C349),
                          ],
                          stops: [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Shine
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Percentage text
                  Center(
                    child: Text(
                      '${(v * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
