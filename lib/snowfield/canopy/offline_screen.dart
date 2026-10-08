import 'package:flutter/material.dart';

import '../../shell/snowfall_buttons.dart';
import '../../shell/snowfall_theme.dart';

/// Shown whenever the pipeline concludes "no network".
///
/// We don't ship a bespoke background art for the no-wifi screen,
/// so the surface is painted procedurally — frosted navy gradient
/// with a snowy flake monogram, matching the game's palette.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: SnowfallTheme.deepIce,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _IcyBackdrop(),
          Positioned(
            left: 0,
            right: 0,
            top: size.height * (landscape ? 0.14 : 0.26),
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.ac_unit_rounded,
                  color: Color(0xFFBEE2FF),
                  size: 86,
                  shadows: <Shadow>[
                    Shadow(color: Color(0x80000000), blurRadius: 12),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'NO INTERNET CONNECTION',
                  textAlign: TextAlign.center,
                  style: SnowfallTheme.titleStyle(size: 26),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Check your connection and try again',
                    textAlign: TextAlign.center,
                    style: SnowfallTheme.bodyStyle(size: 15),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.10 : 0.09),
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF9CD4FF)),
                      ),
                    )
                  : SnowfallPillButton(
                      label: 'Retry',
                      width: landscape ? size.width * 0.30 : size.width * 0.56,
                      onTap: _retry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IcyBackdrop extends StatelessWidget {
  const _IcyBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0A1E3C),
            Color(0xFF061736),
            Color(0xFF030B1F),
          ],
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}
