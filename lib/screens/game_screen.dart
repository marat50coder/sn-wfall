import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../game/cell_widget.dart';
import '../game/currency.dart';
import '../game/slot_model.dart';
import '../widgets/bomb_drop.dart';
import 'wheel_bonus_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _GamePhase { idle, spinning, cascading, scatterAnnounce, wheelIntro }

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final SlotEngine _engine = SlotEngine();
  late List<List<Cell>> _grid;

  // Cells that should be highlighted as matched this cascade.
  Set<int> _matchedThisCascade = {};

  // Cells cleared during current cascade (during clearing animation).
  Set<int> _clearingThisCascade = {};

  // Cells that are "new" in this frame (dropped from top) -> animate in.
  Set<int> _newCells = {};

  // Cells that are actively pulsing to announce a bonus wheel trigger.
  Set<int> _scatterAnnounce = {};

  /// Per-cell drop timing. Reels that start after two scatters have already
  /// landed get a much longer fall so the last reels feel tense.
  final Map<int, int> _dropDelayMs = {};
  final Map<int, int> _dropDurationMs = {};
  bool _scatterSuspense = false;

  _GamePhase _phase = _GamePhase.idle;

  // Fun coins — not real money. This is a for-entertainment-only slot demo.
  double _balance = 5000;
  double _bet = 20;
  double _lastWin = 0.0;
  double _tumbleTotal = 0.0;

  // Background rotates: bg1 (fire/red), bg2 (blue/ice), bg3 (crimson)
  int _bgIndex = 1; // start ice
  static const List<String> _bgAssets = [
    'assets/Snowfall_Odyssey_gameplay_assets/bg2_asset.webp',
    'assets/Snowfall_Odyssey_gameplay_assets/bg1_asset.webp',
    'assets/Snowfall_Odyssey_gameplay_assets/bg3_asset.webp',
  ];

  // Bomb drop animation controller (visual "meteor" before landing).
  bool _showBombDrop = false;
  PrizeTier? _bombDropTier;
  int? _bombDropIndex;

  final List<double> _betLadder = const [10, 20, 50, 100, 250, 500, 1000, 2500];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Hide the status bar + bottom navigation while the slot game is up.
    // immersiveSticky lets the user swipe to momentarily reveal them.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _grid = _engine.rollGrid();
  }

  @override
  void dispose() {
    // Restore the system bars when leaving the slot screen so the menu
    // and permission card look normal again.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _spin() async {
    if (_phase != _GamePhase.idle) return;
    if (_balance < _bet) return;
    final next = _engine.rollGrid();
    final timing = _spinTiming(next);
    setState(() {
      _balance -= _bet;
      _lastWin = 0.0;
      _tumbleTotal = 0.0;
      _matchedThisCascade.clear();
      _clearingThisCascade.clear();
      _phase = _GamePhase.spinning;
      _grid = next;
      _newCells = _allCellIndices();
      _dropDelayMs
        ..clear()
        ..addAll(timing.delayMs);
      _dropDurationMs
        ..clear()
        ..addAll(timing.durationMs);
      _scatterSuspense = timing.suspense;
    });

    await Future.delayed(Duration(milliseconds: timing.totalMs));
    if (!mounted) return;
    setState(() {
      _newCells.clear();
      _scatterSuspense = false;
    });

    // Simulate a bomb dropping from the sky if the initial roll has a bomb prize.
    await _maybeShowBombDropAnimation();

    // Resolve cascades.
    await _resolveCascades();

    if (!mounted) return;
    // If scatters triggered bonus, open wheel.
    final res = _engine.evaluate(_grid, _bet);
    if (res.triggeredBonus) {
      await _announceScatters();
      if (!mounted) return;
      await _openWheelBonus(res.scatterTheme!);
    }
    if (!mounted) return;
    setState(() {
      _phase = _GamePhase.idle;
    });
  }

  /// Highlight all scatter cells with a strong pulse so the player realises a
  /// bonus is about to trigger, then briefly pause before the wheel appears.
  Future<void> _announceScatters() async {
    final positions = _engine.scatterPositions(_grid);
    if (positions.isEmpty) return;
    setState(() {
      _phase = _GamePhase.scatterAnnounce;
      _scatterAnnounce = positions;
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _scatterAnnounce = <int>{};
    });
  }

  /// Fast reels by default. Once two scatters are already on the stopped
  /// reels, every reel still in the air slows down.
  _SpinTiming _spinTiming(List<List<Cell>> grid) {
    final delay = <int, int>{};
    final duration = <int, int>{};
    var cursor = 0;
    var scattersSeen = 0;
    var suspense = false;
    var slowestEnd = 0;
    for (var r = 0; r < SlotConfig.reels; r++) {
      final slow = scattersSeen >= 2;
      if (slow) suspense = true;
      final reelMs = slow ? 980 : 220;
      final rowStep = slow ? 70 : 16;
      for (var y = 0; y < SlotConfig.rows; y++) {
        final idx = r * SlotConfig.rows + y;
        // Bottom row of the reel lands first.
        final rowDelay = (SlotConfig.rows - 1 - y) * rowStep;
        delay[idx] = cursor + rowDelay;
        duration[idx] = reelMs;
        final end = cursor + rowDelay + reelMs;
        if (end > slowestEnd) slowestEnd = end;
      }
      cursor += slow ? 640 : 60;
      for (var y = 0; y < SlotConfig.rows; y++) {
        final cell = grid[r][y];
        if (cell.prizeTier == null && cell.symbol.isScatter) {
          scattersSeen++;
        }
      }
    }
    return _SpinTiming(delay, duration, suspense, slowestEnd + 40);
  }

  Set<int> _allCellIndices() {
    final s = <int>{};
    for (var r = 0; r < SlotConfig.reels; r++) {
      for (var y = 0; y < SlotConfig.rows; y++) {
        s.add(r * SlotConfig.rows + y);
      }
    }
    return s;
  }

  Future<void> _maybeShowBombDropAnimation() async {
    // Find first bomb in current grid.
    for (var r = 0; r < SlotConfig.reels; r++) {
      for (var y = 0; y < SlotConfig.rows; y++) {
        final c = _grid[r][y];
        if (c.prizeTier != null) {
          final idx = r * SlotConfig.rows + y;
          setState(() {
            _showBombDrop = true;
            _bombDropTier = c.prizeTier;
            _bombDropIndex = idx;
          });
          await Future.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;
          setState(() {
            _showBombDrop = false;
            _bombDropTier = null;
            _bombDropIndex = null;
          });
          return;
        }
      }
    }
  }

  Future<void> _resolveCascades() async {
    setState(() => _phase = _GamePhase.cascading);
    var iterations = 0;
    while (mounted && iterations < 20) {
      iterations++;
      final res = _engine.evaluate(_grid, _bet);
      if (!res.hasWin && res.bombPrizes.isEmpty) break;

      // Highlight matches (and bomb positions).
      final toClear = <int>{};
      toClear.addAll(res.matchedPositions.keys);
      toClear.addAll(res.bombPrizes.keys);

      setState(() {
        _matchedThisCascade = toClear.toSet();
      });

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      // Add win amount.
      setState(() {
        _tumbleTotal += res.totalWin;
        _lastWin = _tumbleTotal;
        _balance += res.totalWin;
        _clearingThisCascade = toClear.toSet();
        _matchedThisCascade.clear();
      });
      await Future.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;

      // Tumble: create new grid dropping in from top.
      final oldGridSize = SlotConfig.rows;
      final newGrid = _engine.tumble(_grid, toClear);

      // Determine which cells are "new" in the new grid (had fresh spawnKey created).
      final oldKeys = <int>{};
      for (final col in _grid) {
        for (final c in col) {
          if (c.spawnKey != null) oldKeys.add(c.spawnKey!);
        }
      }
      final freshCells = <int>{};
      for (var r = 0; r < SlotConfig.reels; r++) {
        for (var y = 0; y < oldGridSize; y++) {
          final k = newGrid[r][y].spawnKey;
          if (k == null || !oldKeys.contains(k)) {
            freshCells.add(r * SlotConfig.rows + y);
          }
        }
      }

      final cascadeDelay = <int, int>{};
      final cascadeDuration = <int, int>{};
      for (final idx in freshCells) {
        final y = idx % SlotConfig.rows;
        cascadeDelay[idx] = (SlotConfig.rows - 1 - y) * 18;
        cascadeDuration[idx] = 240;
      }
      setState(() {
        _grid = newGrid;
        _clearingThisCascade.clear();
        _newCells = freshCells;
        _dropDelayMs
          ..clear()
          ..addAll(cascadeDelay);
        _dropDurationMs
          ..clear()
          ..addAll(cascadeDuration);
        _scatterSuspense = false;
      });
      // Wait for cascade drop to settle before evaluating again.
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() => _newCells.clear());
    }
  }

  Future<void> _openWheelBonus(WheelTheme theme) async {
    setState(() => _phase = _GamePhase.wheelIntro);
    final result = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => WheelBonusScreen(theme: theme, bet: _bet),
      ),
    );
    if (!mounted) return;
    final win = result ?? 0.0;
    setState(() {
      _lastWin += win;
      _tumbleTotal += win;
      _balance += win;
      _phase = _GamePhase.idle;
      // Rotate background to match wheel theme mood.
      _bgIndex = switch (theme) {
        WheelTheme.ice => 0,
        WheelTheme.fire => 1,
        WheelTheme.zeus => 2,
        WheelTheme.sweet => 0,
      };
    });
  }

  void _adjustBet(int direction) {
    final idx = _betLadder.indexOf(_bet);
    if (idx == -1) return;
    final newIdx = (idx + direction).clamp(0, _betLadder.length - 1);
    setState(() => _bet = _betLadder[newIdx]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNightBlue,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with subtle Ken Burns.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: Image.asset(
              _bgAssets[_bgIndex],
              key: ValueKey(_bgIndex),
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildGridSection()),
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          _iconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          _titleBadge(),
          const Spacer(),
          _iconBtn(
            icon: Icons.info_outline_rounded,
            onTap: _showRules,
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kAccentGold.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _titleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: kAccentGold, width: 1.5),
      ),
      child: Image.asset(
        'assets/logo/game_name.png',
        height: 46,
        fit: BoxFit.contain,
      ),
    );
  }

  void _showRules() {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: kDeepBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kAccentGold, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'HOW TO PLAY',
                    style: TextStyle(
                      color: kAccentGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• 5×5 grid, 25 winning lines.\n'
                    '• Land 5 or more of the same symbol anywhere to win.\n'
                    '• Winning symbols disappear and new symbols cascade from above (Tumble).\n'
                    '• Bombs occasionally drop with MINI, MINOR, MAJOR or GRAND prizes.\n'
                    '• Land 3+ scatter wheels of the same theme to trigger the Bonus Wheel.\n'
                    '\n'
                    'All winnings are paid in FANS — virtual, for-fun credits. '
                    'This game is not a gambling product and cannot pay out real money.',
                    style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridSection() {
    return LayoutBuilder(builder: (context, c) {
      final horizontalPad = 12.0;
      final verticalPad = 10.0;
      final maxW = c.maxWidth - horizontalPad * 2;
      final maxH = c.maxHeight - verticalPad * 2 - 60;
      final cellCandidateW = maxW / SlotConfig.reels;
      final cellCandidateH = maxH / SlotConfig.rows;
      final cellSize = math.min(cellCandidateW, cellCandidateH);
      final gridW = cellSize * SlotConfig.reels;
      final gridH = cellSize * SlotConfig.rows;

      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPad,
          vertical: verticalPad,
        ),
        child: Column(
          children: [
            _buildDisclaimerStrip(),
            const SizedBox(height: 4),
            if (_scatterSuspense) _buildSuspenseBanner() else _buildWinBanner(),
            const SizedBox(height: 6),
            Center(
              child: SizedBox(
                width: gridW + 16,
                height: gridH + 16,
                child: Stack(
                  children: [
                    // Frame around the grid.
                    Positioned.fill(
                      child: _buildFrame(),
                    ),
                    // Grid cells.
                    Positioned(
                      left: 8,
                      top: 8,
                      width: gridW,
                      height: gridH,
                      child: _buildGridCells(cellSize),
                    ),
                    if (_showBombDrop &&
                        _bombDropTier != null &&
                        _bombDropIndex != null)
                      Positioned.fill(
                        child: BombDrop(
                          tier: _bombDropTier!,
                          targetIndex: _bombDropIndex!,
                          cellSize: cellSize,
                          gridWidth: gridW,
                          gridHeight: gridH,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFrame() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF08122E).withValues(alpha: 0.85),
            const Color(0xFF041028).withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: kAccentGold, width: 3),
        boxShadow: [
          BoxShadow(
            color: kAccentGold.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: kAccentGold.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'FOR FUN ONLY · NOT REAL MONEY · FANS HAVE NO CASH VALUE',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSuspenseBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF7A1E6A), Color(0xFFE23B8A), Color(0xFF7A1E6A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE23B8A).withValues(alpha: 0.7),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Text(
        '2 SCATTERS · HOLD ON',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
    );
  }

  Widget _buildWinBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _lastWin > 0
          ? Container(
              key: ValueKey('win-$_lastWin'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A5A0F), Color(0xFFF5C349), Color(0xFF8A5A0F)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kAccentGold.withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                'TUMBLE WIN  ${formatFans(_lastWin)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 4),
                  ],
                ),
              ),
            )
          : const SizedBox(height: 30),
    );
  }

  Widget _buildGridCells(double cellSize) {
    // ClipRect prevents falling symbols from being visible above the frame
    // during their drop-in animation — they should appear to enter the visible
    // area from the top edge of the reels window.
    return ClipRect(
      child: SizedBox(
        width: cellSize * SlotConfig.reels,
        height: cellSize * SlotConfig.rows,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: _buildCellWidgets(cellSize),
        ),
      ),
    );
  }

  List<Widget> _buildCellWidgets(double cellSize) {
    // Iterate over every cell in the current grid and place it via
    // AnimatedPositioned keyed by the stable spawnKey. Surviving cells will
    // animate smoothly to their new positions after a cascade. New cells get
    // a staggered drop-in delay so the fall reads as a wave across reels.
    final children = <Widget>[];
    for (var r = 0; r < SlotConfig.reels; r++) {
      for (var y = 0; y < SlotConfig.rows; y++) {
        final cell = _grid[r][y];
        final idx = r * SlotConfig.rows + y;
        final key = ValueKey('cell-${cell.spawnKey}');
        final isNew = _newCells.contains(idx);
        final isMatched = _matchedThisCascade.contains(idx);
        final isClearing = _clearingThisCascade.contains(idx);
        final isScatterHighlight = _scatterAnnounce.contains(idx);
        // Reels fall left-to-right; within a reel bottom rows land first so
        // upper cells appear to stack on top of the settled ones.
        final delayMs = isNew ? (_dropDelayMs[idx] ?? 0) : 0;
        final dropMs = isNew ? (_dropDurationMs[idx] ?? 220) : 220;
        children.add(
          AnimatedPositioned(
            key: key,
            duration: Duration(milliseconds: isNew ? 0 : 260),
            curve: Curves.easeOutCubic,
            left: r * cellSize,
            top: y * cellSize,
            width: cellSize,
            height: cellSize,
            child: _AnimatedCell(
              isNew: isNew,
              isClearing: isClearing,
              delayMs: delayMs,
              dropDurationMs: dropMs,
              travelDistance: cellSize * (y + 1.4),
              child: CellWidget(
                cell: cell,
                size: cellSize,
                matched: isMatched,
                scatterHighlight: isScatterHighlight,
              ),
            ),
          ),
        );
      }
    }
    return children;
  }

  Widget _buildBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: kAccentGold, width: 2),
      ),
      child: Row(
        children: [
          _infoBox('BALANCE · $kCurrencyName',
              formatFans(_balance, withUnit: false)),
          const SizedBox(width: 8),
          _buildBetControls(),
          const SizedBox(width: 8),
          _buildSpinButton(),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildBetControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            iconSize: 20,
            onPressed: () => _adjustBet(-1),
            icon: const Icon(Icons.remove_circle, color: Colors.white),
          ),
          Column(
            children: [
              const Text('BET',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4)),
              Text(formatFans(_bet, withUnit: false),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            iconSize: 20,
            onPressed: () => _adjustBet(1),
            icon: const Icon(Icons.add_circle, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinButton() {
    final busy = _phase != _GamePhase.idle;
    return GestureDetector(
      onTap: busy ? null : _spin,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: busy
                ? [const Color(0xFF555555), const Color(0xFF333333)]
                : const [Color(0xFFFFE28C), Color(0xFFE0A93A), Color(0xFF8A5A0F)],
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: (busy ? Colors.grey : kAccentGold).withValues(alpha: 0.6),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              )
            : const Icon(Icons.autorenew_rounded, size: 42, color: Colors.white),
      ),
    );
  }
}

class _SpinTiming {
  const _SpinTiming(this.delayMs, this.durationMs, this.suspense, this.totalMs);
  final Map<int, int> delayMs;
  final Map<int, int> durationMs;
  final bool suspense;
  final int totalMs;
}

class _AnimatedCell extends StatefulWidget {
  const _AnimatedCell({
    required this.child,
    required this.isNew,
    required this.isClearing,
    this.delayMs = 0,
    this.dropDurationMs = 220,
    this.travelDistance = 240,
  });

  final Widget child;
  final bool isNew;
  final bool isClearing;

  /// Milliseconds to delay a drop-in animation. Used to stagger the fall
  /// across reels and rows so the grid fills in as a cascade instead of all
  /// at once.
  final int delayMs;

  /// How long this symbol takes to fall. Suspense reels use a much larger value.
  final int dropDurationMs;

  /// How far (in pixels) the cell should travel down from its start position.
  /// Cells sitting higher on the grid must travel further than cells landing
  /// at the bottom, so they visually appear to fall past the ones already
  /// settled below.
  final double travelDistance;

  @override
  State<_AnimatedCell> createState() => _AnimatedCellState();
}

class _AnimatedCellState extends State<_AnimatedCell>
    with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.dropDurationMs),
    value: widget.isNew ? 0.0 : 1.0,
  );
  late final AnimationController _clear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _drop.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isClearing && !oldWidget.isClearing) {
      _clear.reverse();
    }
  }

  @override
  void dispose() {
    _drop.dispose();
    _clear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_drop, _clear]),
      builder: (context, child) {
        // Drop-in: bouncy easing so the cell settles with a tiny compress.
        final dv = Curves.easeOutCubic.transform(_drop.value);
        final overshoot = _drop.value < 1.0
            ? 0.0
            : (1.0 - _drop.value); // reserved for future overshoot tweak
        final dy = widget.isNew
            ? -widget.travelDistance * (1 - dv) + overshoot * 6
            : 0.0;

        final cv = _clear.value;
        // Clear-out: shrink and fade with a slight rotation for flair.
        final scale = widget.isClearing ? cv : 1.0;
        final opacity = widget.isClearing ? cv : 1.0;
        final rot = widget.isClearing ? (1 - cv) * 0.35 : 0.0;

        // Squash-and-stretch when landing at the last 15% of the drop.
        double landingScaleY = 1.0;
        double landingScaleX = 1.0;
        if (widget.isNew && dv > 0.85) {
          final t = ((dv - 0.85) / 0.15).clamp(0.0, 1.0);
          final squash = math.sin(t * math.pi) * 0.08;
          landingScaleY = 1.0 - squash;
          landingScaleX = 1.0 + squash;
        }

        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(
                scaleX: scale * landingScaleX,
                scaleY: scale * landingScaleY,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
