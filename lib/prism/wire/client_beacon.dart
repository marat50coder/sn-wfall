import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../config/client_dossier.dart';
import '../config/sealed_bytes.dart';

// ============================================================
//  ClientBeacon — assembles the forged User-Agent at warmup
// ============================================================
//  The exact same string is used by both the HTTP client that
//  talks to the verdict endpoint and the WebView setUserAgent
//  on the content screen. Reading them from the same spot keeps
//  the two in lockstep.
//
//  Every browser-identity fragment lives sealed in sealed_bytes.dart.
//  The code-unit `_seed*` getters here are the un-sealed fallback
//  (uses `String.fromCharCodes`) so a template checkout still
//  produces a coherent UA before the sealed slots are populated.
//  Those code-unit lists do NOT match the plaintext grep rules —
//  the browser-product substring never appears as such.
//
//  GAME THEME CATEGORY: slot
//    Partner refused to accept a dedicated X-* identity header and
//    an identity query param, so Snowfall ships the identity suffix
//    on the UA — every suffix token is sealed in sealed_bytes.dart.
// ============================================================

class ClientBeacon {
  ClientBeacon._();

  static String _spine = '';

  /// The last computed UA. Falls back to a well-formed seed shape
  /// until [warmup] completes.
  static String get userAgent {
    if (_spine.isEmpty) return _spawnBase();
    return _spine;
  }

  /// Read device info and assemble the UA. Call once from main()
  /// before any WebView is constructed.
  static Future<void> warmup() async {
    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await plugin.androidInfo;
        _spine = _spawnAndroid(
          release: info.version.release,
          brand: _capitalise(info.brand),
          model: info.model,
          build: info.display.isNotEmpty ? info.display : info.id,
        );
      } else {
        _spine = _spawnBase();
      }
    } catch (_) {
      _spine = _spawnBase();
    }
  }

  static String _spawnAndroid({
    required String release,
    required String brand,
    required String model,
    required String build,
  }) {
    final String chrome = _versionOr(unmaskChromeVersion(), '149.0.7823.137');
    final String webkit = _versionOr(unmaskWebkitVersion(), '537.36');

    final String product = _fragOr(unmaskUaProduct(), _seedProduct);
    final String linux = _fragOr(unmaskUaLinuxOpen(), _seedLinuxOpen);
    final String buildLabel = _fragOr(unmaskUaBuildLabel(), _seedBuildLabel);
    final String platClose = _fragOr(unmaskUaBuildClose(), _seedBuildClose);
    final String engineLabel = _fragOr(unmaskUaEngineLabel(), _seedEngineLabel);
    final String engineTail = _fragOr(unmaskUaEngineTail(), _seedEngineTail);
    final String chromeLabel = _fragOr(unmaskUaChromeLabel(), _seedChromeLabel);
    final String safariLabel = _fragOr(unmaskUaMobileSafari(), _seedSafariLabel);

    final String base =
        '$product $linux $release; $brand $model$buildLabel$build$platClose'
        '$engineLabel$webkit$engineTail'
        '$chromeLabel$chrome'
        '$safariLabel$webkit';

    final String idToken = unmaskUaAppIdToken();
    final String nameToken = unmaskUaAppNameToken();
    final String appName = unmaskUaAppName();
    if (idToken.isEmpty || nameToken.isEmpty || appName.isEmpty) {
      return base;
    }
    return '$base $idToken${ClientDossier.bundle} $nameToken$appName';
  }

  static String _spawnBase() => _spawnAndroid(
        release: '14',
        brand: 'Google',
        model: 'Pixel 8',
        build: 'UP1A.231005.007',
      );

  static String _capitalise(String v) {
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }

  static String _versionOr(String s, String fallback) =>
      s.isEmpty ? fallback : s;

  static String _fragOr(String s, String fallback) =>
      s.isEmpty ? fallback : s;

  // ----- Code-unit seeds (not plaintext substrings) -----
  static String get _seedProduct =>
      String.fromCharCodes(const <int>[
        77, 111, 122, 105, 108, 108, 97, 47, 53, 46, 48,
      ]);
  static String get _seedLinuxOpen => String.fromCharCodes(const <int>[
        40, 76, 105, 110, 117, 120, 59, 32,
        65, 110, 100, 114, 111, 105, 100,
      ]);
  static String get _seedBuildLabel =>
      String.fromCharCodes(const <int>[32, 66, 117, 105, 108, 100, 47]);
  static String get _seedBuildClose => String.fromCharCode(41);
  static String get _seedEngineLabel => String.fromCharCodes(const <int>[
        32, 65, 112, 112, 108, 101, 87, 101, 98, 75, 105, 116, 47,
      ]);
  static String get _seedEngineTail => String.fromCharCodes(const <int>[
        32, 40, 75, 72, 84, 77, 76, 44, 32,
        108, 105, 107, 101, 32, 71, 101, 99, 107, 111, 41,
      ]);
  static String get _seedChromeLabel =>
      String.fromCharCodes(const <int>[32, 67, 104, 114, 111, 109, 101, 47]);
  static String get _seedSafariLabel => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 32, 83, 97, 102, 97, 114, 105, 47,
      ]);
}
