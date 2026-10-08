import 'dart:async';
import 'dart:io';

import 'dossier/client_dossier.dart';
import 'trail/step_verdict.dart';
import 'circuit/aurora_vault.dart';
import 'circuit/cold_beacon.dart';
import 'circuit/net_sensor.dart';
import 'circuit/verdict_hub.dart';
import 'circuit/push_dispatch.dart';
import 'circuit/install_registry.dart';

// ============================================================
//  SnowfieldDirector — the single entry point for boot routing
// ============================================================
//  `plan(onTick)` returns a sealed `StepVerdict`. The boot
//  canvas pattern-matches it and pushes exactly one route; no
//  routing logic lives anywhere else.
//
//  Decision shape by last known branch:
//
//    initial (first launch)
//      ├─ no adapter        → OutageStep
//      ├─ DNS probe fails   → OutageStep
//      ├─ verdict approved  → remember surface → SurfaceStep(url)
//      └─ verdict rejected  → remember grid    → GridStep
//
//    surface (was in WebView)
//      ├─ no adapter        → OutageStep
//      ├─ cold-tap URL      → SurfaceStep(url, coldTap)
//      ├─ fresh cached URL  → SurfaceStep(cached)
//      ├─ verdict approved  → SurfaceStep(fresh)
//      ├─ verdict rejected but cache exists
//      │                    → SurfaceStep(cached)  (last-known-good)
//      └─ otherwise         → OutageStep
//
//    grid (was in native game)
//      ├─ no adapter        → GridStep
//      ├─ verdict approved  → remember surface → SurfaceStep(url)
//      └─ verdict rejected  → GridStep
//
//  Concurrent plans de-dupe on an in-flight future, so a double
//  build of the boot canvas does not fire two POSTs. The cache
//  clears on completion so a Retry re-runs the pipeline fresh.
// ============================================================

class SnowfieldDirector {
  SnowfieldDirector({
    required this.vault,
    required this.sensor,
    required this.bureau,
    required this.endpoint,
    required this.relay,
  });

  final AuroraVault vault;
  final NetSensor sensor;
  final InstallRegistry bureau;
  final VerdictHub endpoint;
  final PushDispatch relay;

  Future<StepVerdict>? _inFlight;

  Future<StepVerdict> plan({void Function(double)? onTick}) {
    return _inFlight ??= _plan(onTick ?? (_) {})
        .whenComplete(() => _inFlight = null);
  }

  Future<StepVerdict> _plan(void Function(double) onTick) async {
    if (!ClientDossier.credentialsReady) {
      onTick(1);
      return const GridStep();
    }

    relay.onTokenRolled = _onTokenRolled;

    // Ignite the push relay first so `getInitialMessage()` has a chance
    // to run and park the cold-tap URL into the vault *before* we try to
    // consume it. Without this, a killed-state notification tap would
    // fall through to the normal boot path and land on the default URL.
    try {
      await relay.ignite();
    } catch (_) {}

    final String? coldTapUrl = await ColdBeacon.consume(vault);
    if (coldTapUrl != null && coldTapUrl.isNotEmpty) {
      await vault.rememberRoute(ContactMemo.surface);
      unawaited(_rebootSignals());
      onTick(1);
      return SurfaceStep(coldTapUrl, coldTap: true);
    }

    onTick(0.18);
    return switch (vault.route) {
      ContactMemo.initial => _planInitial(onTick),
      ContactMemo.surface => _planReturningSurface(onTick),
      ContactMemo.grid => _planReturningGrid(onTick),
    };
  }

  Future<StepVerdict> _planInitial(void Function(double) onTick) async {
    if (!await sensor.hasAdapter()) {
      return const OutageStep();
    }
    onTick(0.32);
    try {
      await relay.ignite();
    } catch (_) {}
    if (!await sensor.canDialOut()) {
      return const OutageStep();
    }
    onTick(0.5);
    await bureau.ignite();
    await bureau.settleWithin(
      installSeconds: ClientDossier.firstInstallWaitSec,
    );
    onTick(0.78);
    final VerdictReply reply = await _ask();
    onTick(1);
    if (reply.hasTarget) {
      await vault.rememberRoute(ContactMemo.surface);
      return SurfaceStep(reply.target!);
    }
    await vault.rememberRoute(ContactMemo.grid);
    return const GridStep();
  }

  Future<StepVerdict> _planReturningSurface(
      void Function(double) onTick) async {
    if (!await sensor.hasAdapter()) {
      return const OutageStep();
    }
    final String? cached = await vault.cachedTarget();
    if (cached != null && !vault.cachedTargetStale) {
      onTick(1);
      return SurfaceStep(cached);
    }

    await Future.wait<void>(<Future<void>>[
      relay.ignite(),
      bureau.ignite(),
    ]);
    if (!await sensor.canDialOut()) {
      if (cached != null) {
        return SurfaceStep(cached);
      }
      return const OutageStep();
    }
    onTick(0.6);
    await bureau.settleWithin(
      installSeconds: ClientDossier.returningInstallWaitSec,
    );
    final VerdictReply reply = await _ask();
    onTick(1);
    if (reply.hasTarget) return SurfaceStep(reply.target!);
    if (cached != null) return SurfaceStep(cached);
    return const OutageStep();
  }

  Future<StepVerdict> _planReturningGrid(
      void Function(double) onTick) async {
    if (!await sensor.hasAdapter()) {
      onTick(1);
      return const GridStep();
    }
    await Future.wait<void>(<Future<void>>[
      relay.ignite(),
      bureau.ignite(),
    ]);
    if (!await sensor.canDialOut()) {
      onTick(1);
      return const GridStep();
    }
    onTick(0.58);
    await bureau.settleWithin(
      installSeconds: ClientDossier.returningInstallWaitSec,
    );
    final VerdictReply reply = await _ask();
    onTick(1);
    if (!reply.hasTarget) return const GridStep();
    await vault.rememberRoute(ContactMemo.surface);
    return SurfaceStep(reply.target!);
  }

  Future<VerdictReply> _ask({String? token}) async {
    final Map<String, dynamic> body = await bureau.compile(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? relay.token,
    );
    return endpoint.query(body);
  }

  Future<void> _rebootSignals() async {
    try {
      await Future.wait<void>(<Future<void>>[
        relay.ignite(),
        bureau.ignite(),
      ]);
      await bureau.settleWithin(
        installSeconds: ClientDossier.returningInstallWaitSec,
      );
      await _ask();
    } catch (_) {}
  }

  Future<void> _onTokenRolled(String token) async {
    try {
      await _ask(token: token);
    } catch (_) {}
  }
}
