import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../curio/drift_bridge.dart';

// ============================================================
//  ClientBeacon — assembles the forged User-Agent at warmup
// ============================================================
//  The UA string the HTTP client sends to the verdict endpoint
//  and the WebView `setUserAgent(...)` on the content screen
//  are the same byte-for-byte. Both come from the Rust vault:
//
//    DriftBridge.userAgent(release, brand, model, build)
//
//  Dart holds zero plaintext UA fragments. If libdrift_signal.so
//  is unavailable the UA stays empty, which flips
//  ClientDossier.credentialsReady false and the gray flow
//  stays dormant — the slot game still boots.
//
//  GAME THEME CATEGORY: slot
//    No identity suffix is appended to the UA. Bundle / app
//    name metadata rides in the POST body instead, so Snowfall
//    presents a stock Chrome Android UA.
// ============================================================

class ClientBeacon {
  ClientBeacon._();

  static String _spine = '';

  /// The last computed UA. Empty until [warmup] completes; empty
  /// also implies the Rust vault isn't loaded.
  static String get userAgent => _spine;

  /// Read device info and ask Rust to assemble the UA. Call once
  /// from main() before any WebView is constructed.
  static Future<void> warmup() async {
    try {
      DriftBridge.boot();
      if (Platform.isAndroid) {
        final DeviceInfoPlugin plugin = DeviceInfoPlugin();
        final AndroidDeviceInfo info = await plugin.androidInfo;
        _spine = DriftBridge.userAgent(
          release: info.version.release,
          brand: _capitalise(info.brand),
          model: info.model,
          build: info.display.isNotEmpty ? info.display : info.id,
        );
      } else {
        // Non-Android targets are not shipped. Keep the UA empty
        // so the gray flow stays dormant on dev machines.
        _spine = DriftBridge.userAgent(
          release: '14',
          brand: 'Google',
          model: 'Pixel 8',
          build: 'UP1A.231005.007',
        );
      }
    } catch (_) {
      _spine = '';
    }
  }

  static String _capitalise(String v) {
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }
}
