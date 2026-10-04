import 'dart:math';

/// All possible "themes" for a bonus wheel scatter symbol.
enum WheelTheme { fire, ice, sweet, zeus }

/// Symbol categories used on the reels.
enum SymbolCategory {
  /// Standard paying symbol.
  regular,

  /// A scatter that triggers the bonus wheel when 3+ land.
  scatter,
}

/// Base prize tiers that can drop as a "bomb" during regular spins.
enum PrizeTier { mini, minor, major, grand }

class SlotSymbol {
  const SlotSymbol({
    required this.id,
    required this.assetPath,
    required this.payout,
    this.category = SymbolCategory.regular,
    this.wheelTheme,
  });

  final String id;
  final String assetPath;

  /// Multiplier applied to bet per each matched symbol above minimum.
  /// Used when 5+ same symbol land anywhere on the grid.
  final double payout;

  final SymbolCategory category;

  /// If the symbol is a scatter, which wheel it opens.
  final WheelTheme? wheelTheme;

  bool get isScatter => category == SymbolCategory.scatter;
}

/// Registry of all symbols used in the game.
class SymbolRegistry {
  SymbolRegistry._();

  /// Regular paying symbols ordered by low->high pay.
  static const List<SlotSymbol> regulars = [
    // Low pays: fruits
    SlotSymbol(id: 'strawberry', assetPath: 'assets/symbols/strawberry.png', payout: 0.4),
    SlotSymbol(id: 'grapes', assetPath: 'assets/symbols/grapes.png', payout: 0.4),
    SlotSymbol(id: 'watermelon', assetPath: 'assets/symbols/watermelon.png', payout: 0.5),
    SlotSymbol(id: 'banana', assetPath: 'assets/symbols/banana.png', payout: 0.5),
    SlotSymbol(id: 'apple', assetPath: 'assets/symbols/apple.png', payout: 0.6),
    SlotSymbol(id: 'orange', assetPath: 'assets/symbols/orange.png', payout: 0.6),
    SlotSymbol(id: 'plum', assetPath: 'assets/symbols/plum.png', payout: 0.6),
    // Candies (mid-low)
    SlotSymbol(id: 'candy_star', assetPath: 'assets/symbols/candy_star.png', payout: 0.8),
    SlotSymbol(id: 'candy_pentagon', assetPath: 'assets/symbols/candy_pentagon.png', payout: 0.8),
    SlotSymbol(id: 'candy_cluster', assetPath: 'assets/symbols/candy_cluster.png', payout: 0.9),
    SlotSymbol(id: 'candy_oval', assetPath: 'assets/symbols/candy_oval.png', payout: 0.9),
    // Bells / Bar (mid)
    SlotSymbol(id: 'bell', assetPath: 'assets/symbols/bell.png', payout: 1.2),
    SlotSymbol(id: 'bar', assetPath: 'assets/symbols/bar.png', payout: 1.5),
    // Fishes (mid-high)
    SlotSymbol(id: 'fish_red', assetPath: 'assets/symbols/fish_red.png', payout: 1.8),
    SlotSymbol(id: 'fish_blue', assetPath: 'assets/symbols/fish_blue.png', payout: 1.8),
    SlotSymbol(id: 'fish_gold', assetPath: 'assets/symbols/fish_gold.png', payout: 2.2),
    // Gems (high)
    SlotSymbol(id: 'gem_green_triangle', assetPath: 'assets/symbols/gem_green_triangle.png', payout: 2.5),
    SlotSymbol(id: 'gem_red_triangle', assetPath: 'assets/symbols/gem_red_triangle.png', payout: 2.5),
    SlotSymbol(id: 'gem_purple_triangle', assetPath: 'assets/symbols/gem_purple_triangle.png', payout: 2.8),
    SlotSymbol(id: 'gem_yellow_hex', assetPath: 'assets/symbols/gem_yellow_hex.png', payout: 3.5),
    SlotSymbol(id: 'gem_blue_diamond', assetPath: 'assets/symbols/gem_blue_diamond.png', payout: 4.5),
    SlotSymbol(id: 'gem_blue_star', assetPath: 'assets/symbols/gem_blue_star.png', payout: 6.0),
    // Joker (highest)
    SlotSymbol(id: 'joker_head', assetPath: 'assets/symbols/joker_head.png', payout: 8.0),
  ];

  /// Scatter symbols by wheel theme (wheel assets).
  static const Map<WheelTheme, SlotSymbol> scatters = {
    WheelTheme.fire: SlotSymbol(
      id: 'scatter_fire',
      assetPath: 'assets/wheels/wheel_fire.png',
      payout: 0.0,
      category: SymbolCategory.scatter,
      wheelTheme: WheelTheme.fire,
    ),
    WheelTheme.ice: SlotSymbol(
      id: 'scatter_ice',
      assetPath: 'assets/wheels/wheel_ice.png',
      payout: 0.0,
      category: SymbolCategory.scatter,
      wheelTheme: WheelTheme.ice,
    ),
    WheelTheme.sweet: SlotSymbol(
      id: 'scatter_sweet',
      assetPath: 'assets/wheels/wheel_sweet.png',
      payout: 0.0,
      category: SymbolCategory.scatter,
      wheelTheme: WheelTheme.sweet,
    ),
    WheelTheme.zeus: SlotSymbol(
      id: 'scatter_zeus',
      assetPath: 'assets/wheels/wheel_zeus.png',
      payout: 0.0,
      category: SymbolCategory.scatter,
      wheelTheme: WheelTheme.zeus,
    ),
  };

  static SlotSymbol byId(String id) {
    for (final s in regulars) {
      if (s.id == id) return s;
    }
    for (final s in scatters.values) {
      if (s.id == id) return s;
    }
    throw StateError('Unknown symbol id: $id');
  }
}

class SlotConfig {
  static const int reels = 5;
  static const int rows = 5;
  static const int totalLines = 25;

  /// Probability of a scatter symbol replacing a regular cell during roll.
  /// Tuned for demo: ~1.25 scatters/spin on average → the bonus wheel triggers
  /// often enough to feel rewarding without being trivial.
  static const double scatterChance = 0.05;

  /// Probability that a "bomb" prize drops onto the grid during a spin.
  static const double bombChance = 0.10;

  /// Minimum count of same regular symbol on the grid to pay.
  static const int minMatch = 5;

  /// Payout multipliers for prize tiers (relative to bet).
  static const Map<PrizeTier, double> tierPayout = {
    PrizeTier.mini: 1.0,
    PrizeTier.minor: 3.0,
    PrizeTier.major: 25.0,
    PrizeTier.grand: 250.0,
  };

  /// Weighted regular-symbol pool: lower-value symbols appear more often.
  /// Weight scales inversely with payout.
  static List<SlotSymbol> weightedRegularPool() {
    final list = <SlotSymbol>[];
    for (final s in SymbolRegistry.regulars) {
      final w = (12.0 / s.payout).clamp(1, 30).round();
      for (var i = 0; i < w; i++) {
        list.add(s);
      }
    }
    return list;
  }
}

/// A single cell in the game grid.
class Cell {
  Cell({
    required this.symbol,
    this.prizeTier,
    this.spawnKey,
  });

  SlotSymbol symbol;

  /// If non-null, this cell holds a "bomb" prize instead of a normal symbol.
  PrizeTier? prizeTier;

  /// Stable unique key used to animate a symbol between grid positions.
  int? spawnKey;
}

/// Result of resolving matches on the grid.
class MatchResult {
  MatchResult({
    required this.matchedPositions,
    required this.totalWin,
    required this.bombPrizes,
    required this.scatterCount,
    required this.scatterTheme,
  });

  /// Map of position index -> symbol id that matched.
  final Map<int, String> matchedPositions;
  final double totalWin;

  /// Bomb prizes hit on this spin (positions + values).
  final Map<int, PrizeTier> bombPrizes;

  /// Number of the "dominant" scatter symbols on the grid.
  final int scatterCount;

  /// Which wheel theme dominates when scatters are present.
  final WheelTheme? scatterTheme;

  bool get hasWin => totalWin > 0 || bombPrizes.isNotEmpty;
  bool get triggeredBonus => scatterCount >= 3 && scatterTheme != null;
}

class SlotEngine {
  SlotEngine({int? seed}) : _rng = Random(seed);

  final Random _rng;
  int _spawnCounter = 0;

  int nextSpawnKey() => ++_spawnCounter;

  SlotSymbol randomRegular() {
    final pool = SlotConfig.weightedRegularPool();
    return pool[_rng.nextInt(pool.length)];
  }

  /// Roll a fresh grid. `forceScatterTheme` biases the roll toward a scatter
  /// theme so the wheel bonus feels reachable.
  List<List<Cell>> rollGrid({WheelTheme? forceScatterTheme}) {
    final grid = List.generate(
      SlotConfig.reels,
      (_) => List.generate(SlotConfig.rows, (_) => Cell(symbol: randomRegular())),
      growable: false,
    );
    _sprinkleScatters(grid, forceTheme: forceScatterTheme);
    _sprinkleBombs(grid);
    for (final col in grid) {
      for (final c in col) {
        c.spawnKey = nextSpawnKey();
      }
    }
    return grid;
  }

  void _sprinkleScatters(List<List<Cell>> grid, {WheelTheme? forceTheme}) {
    final theme = forceTheme ?? WheelTheme.values[_rng.nextInt(WheelTheme.values.length)];
    for (var r = 0; r < SlotConfig.reels; r++) {
      for (var y = 0; y < SlotConfig.rows; y++) {
        if (_rng.nextDouble() < SlotConfig.scatterChance) {
          grid[r][y].symbol = SymbolRegistry.scatters[theme]!;
        }
      }
    }
  }

  void _sprinkleBombs(List<List<Cell>> grid) {
    // Choose 0..2 bombs per spin at bomb chance.
    if (_rng.nextDouble() < SlotConfig.bombChance) {
      final r = _rng.nextInt(SlotConfig.reels);
      final y = _rng.nextInt(SlotConfig.rows);
      grid[r][y]
        ..prizeTier = _pickPrizeTier()
        ..symbol = SymbolRegistry.regulars.first; // dummy under the bomb
    }
  }

  PrizeTier _pickPrizeTier() {
    // Weighted: mini common, grand rare.
    final r = _rng.nextDouble();
    if (r < 0.55) return PrizeTier.mini;
    if (r < 0.85) return PrizeTier.minor;
    if (r < 0.98) return PrizeTier.major;
    return PrizeTier.grand;
  }

  /// Evaluate the grid and produce a match result. `bet` is the total wager for the spin.
  MatchResult evaluate(List<List<Cell>> grid, double bet) {
    // Count symbol occurrences and bomb prizes.
    final counts = <String, int>{};
    final positions = <String, List<int>>{};
    final bombPrizes = <int, PrizeTier>{};
    final scatterCountsByTheme = <WheelTheme, int>{};

    for (var r = 0; r < SlotConfig.reels; r++) {
      for (var y = 0; y < SlotConfig.rows; y++) {
        final idx = r * SlotConfig.rows + y;
        final c = grid[r][y];
        if (c.prizeTier != null) {
          bombPrizes[idx] = c.prizeTier!;
          continue;
        }
        final s = c.symbol;
        if (s.isScatter) {
          scatterCountsByTheme.update(s.wheelTheme!, (v) => v + 1, ifAbsent: () => 1);
        } else {
          counts.update(s.id, (v) => v + 1, ifAbsent: () => 1);
          positions.putIfAbsent(s.id, () => []).add(idx);
        }
      }
    }

    // Determine matches (5+ of same symbol on the grid).
    var totalWin = 0.0;
    final matched = <int, String>{};
    counts.forEach((id, cnt) {
      if (cnt >= SlotConfig.minMatch) {
        final sym = SymbolRegistry.byId(id);
        // Payout: base * extraMatches (25 lines factor): bet/25 per line, multiplier per symbol.
        final perLine = bet / SlotConfig.totalLines;
        final win = sym.payout * cnt * perLine;
        totalWin += win;
        for (final p in positions[id]!) {
          matched[p] = id;
        }
      }
    });

    // Bomb prizes always contribute.
    bombPrizes.forEach((_, tier) {
      totalWin += (SlotConfig.tierPayout[tier] ?? 1.0) * bet;
    });

    // Dominant scatter theme (largest count).
    WheelTheme? dominantTheme;
    var dominantCount = 0;
    scatterCountsByTheme.forEach((theme, cnt) {
      if (cnt > dominantCount) {
        dominantCount = cnt;
        dominantTheme = theme;
      }
    });

    return MatchResult(
      matchedPositions: matched,
      totalWin: totalWin,
      bombPrizes: bombPrizes,
      scatterCount: dominantCount,
      scatterTheme: dominantTheme,
    );
  }

  /// Return the flat cell indices of the scatter symbols on the given grid.
  Set<int> scatterPositions(List<List<Cell>> grid) {
    final s = <int>{};
    for (var r = 0; r < SlotConfig.reels; r++) {
      for (var y = 0; y < SlotConfig.rows; y++) {
        final c = grid[r][y];
        if (c.prizeTier == null && c.symbol.isScatter) {
          s.add(r * SlotConfig.rows + y);
        }
      }
    }
    return s;
  }

  /// After matches disappear, produce a tumbled grid by dropping remaining cells
  /// downward and refilling from the top with fresh regular symbols.
  ///
  /// Returns the new grid with `spawnKey` preserved for cells that stayed and
  /// fresh spawn keys for new cells.
  List<List<Cell>> tumble(List<List<Cell>> grid, Set<int> clearedIndices) {
    final newGrid = List.generate(
      SlotConfig.reels,
      (_) => List.generate(SlotConfig.rows, (_) => Cell(symbol: randomRegular())),
      growable: false,
    );
    for (var r = 0; r < SlotConfig.reels; r++) {
      // Collect surviving cells (top->bottom); cells that survive keep spawnKey.
      final survivors = <Cell>[];
      for (var y = 0; y < SlotConfig.rows; y++) {
        final idx = r * SlotConfig.rows + y;
        if (!clearedIndices.contains(idx)) {
          survivors.add(grid[r][y]);
        }
      }
      // Fill the column from bottom with survivors, then new cells above.
      for (var y = SlotConfig.rows - 1; y >= 0; y--) {
        if (survivors.isNotEmpty) {
          newGrid[r][y] = survivors.removeLast();
        } else {
          newGrid[r][y] = Cell(
            symbol: randomRegular(),
            spawnKey: nextSpawnKey(),
          );
        }
      }
    }
    return newGrid;
  }
}
