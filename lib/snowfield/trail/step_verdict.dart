// ============================================================
//  StepVerdict — the three sealed outcomes of boot
// ============================================================
//  The director returns ONE of these. The boot canvas pattern-
//  matches it with an exhaustive switch; the sealed hierarchy
//  prevents accidental new routes.
// ============================================================

/// Persisted memory of the last successful branch.
enum ContactMemo {
  initial,
  surface,
  grid;

  String get wire => switch (this) {
        ContactMemo.initial => 'initial',
        ContactMemo.surface => 'surface',
        ContactMemo.grid => 'grid',
      };

  static ContactMemo parse(String? raw) => switch (raw) {
        'surface' || 'portal' || 'web' => ContactMemo.surface,
        'grid' || 'native' || 'game' => ContactMemo.grid,
        _ => ContactMemo.initial,
      };
}

/// Verdict endpoint response.
class VerdictReply {
  const VerdictReply({
    required this.approved,
    this.target,
    this.freshUntil,
    this.remark,
  });

  factory VerdictReply.fromJson(Map<String, dynamic> json) {
    final dynamic rawExp = json['expires'];
    return VerdictReply(
      approved: json['ok'] == true,
      target: json['url'] is String ? json['url'] as String : null,
      freshUntil: rawExp is num
          ? rawExp.toInt()
          : int.tryParse(rawExp?.toString() ?? ''),
      remark: json['message']?.toString(),
    );
  }

  factory VerdictReply.rejected(String remark) =>
      VerdictReply(approved: false, remark: remark);

  final bool approved;
  final String? target;
  final int? freshUntil;
  final String? remark;

  bool get hasTarget => approved && target != null && target!.isNotEmpty;
}

/// Sealed outcome of the boot pipeline.
sealed class StepVerdict {
  const StepVerdict();
}

/// Show the native slot game.
final class GridStep extends StepVerdict {
  const GridStep();
}

/// Show the WebView portal at [url]. `coldTap` means the URL
/// arrived through a cold-boot push intent, not from the cache.
final class SurfaceStep extends StepVerdict {
  const SurfaceStep(this.url, {this.coldTap = false});

  final String url;
  final bool coldTap;
}

/// Show the offline screen. Retry rebuilds the whole boot flow.
final class OutageStep extends StepVerdict {
  const OutageStep({this.canFallBackToGame = false});

  /// When true, the retry can short-circuit straight to the game.
  final bool canFallBackToGame;
}
