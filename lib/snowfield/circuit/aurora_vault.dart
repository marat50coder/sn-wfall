import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dossier/client_dossier.dart';
import '../trail/step_verdict.dart';

// ============================================================
//  AuroraVault — persisted state (prefs + encrypted storage)
// ============================================================
//  Public flags + timestamps live in SharedPreferences; URLs
//  live in platform-encrypted secure storage. All key names are
//  generic ("mode", "pl", "cl") so a dump of SharedPreferences
//  never reveals intent.
//
//  The `_tag` prefix is a short random ASCII token specific to
//  Snowfall. Sibling apps use `rl3_`, `vp8_`, etc.; Snowfall uses
//  `snf_` — not the slug ("snowfall_") which would be a trivial
//  cross-cluster fingerprint.
// ============================================================

const String _tag = 'snf_';

class AuroraVault {
  AuroraVault({FlutterSecureStorage? secure})
      : _crypt = secure ?? const FlutterSecureStorage();

  static const String _keyRoute = '${_tag}route';
  static const String _keyCachedUrl = '${_tag}dst';
  static const String _keyCachedExpiry = '${_tag}dst_ttl';
  static const String _keyPushSnooze = '${_tag}perm_until';
  static const String _keyPushGranted = '${_tag}perm_ok';
  static const String _keyPushOsBlock = '${_tag}perm_os_no';
  static const String _keyColdUrl = '${_tag}pending';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _crypt;

  Future<void> warmup() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ----- Routing memory -----
  ContactMemo get route => ContactMemo.parse(_prefs.getString(_keyRoute));

  Future<void> rememberRoute(ContactMemo value) =>
      _prefs.setString(_keyRoute, value.wire);

  // ----- Cached destination URL (encrypted) -----
  Future<String?> cachedTarget() => _crypt.read(key: _keyCachedUrl);

  Future<void> stashTarget(String url, int? expiresUnix) async {
    await _crypt.write(key: _keyCachedUrl, value: url);
    if (expiresUnix != null) {
      await _prefs.setInt(_keyCachedExpiry, expiresUnix);
    } else {
      await _prefs.setInt(
        _keyCachedExpiry,
        _nowSec() + ClientDossier.cachedUrlLifeSec,
      );
    }
  }

  bool get cachedTargetStale {
    final int? until = _prefs.getInt(_keyCachedExpiry);
    if (until == null) return true;
    return _nowSec() >= until;
  }

  // ----- Push permission state -----
  bool get pushGranted => _prefs.getBool(_keyPushGranted) ?? false;
  Future<void> markPushGranted(bool v) =>
      _prefs.setBool(_keyPushGranted, v);

  bool get pushOsBlocked => _prefs.getBool(_keyPushOsBlock) ?? false;
  Future<void> markPushOsBlocked() =>
      _prefs.setBool(_keyPushOsBlock, true);

  Future<void> stashPushSnooze(int unixSeconds) =>
      _prefs.setInt(_keyPushSnooze, unixSeconds);

  /// Should the push-invite card come up before the WebView?
  /// Returns false once the OS has denied for good (API 33+
  /// permanently suppresses the prompt after a first denial).
  bool get shouldOfferPush {
    if (pushGranted) return false;
    if (pushOsBlocked) return false;
    final int? until = _prefs.getInt(_keyPushSnooze);
    if (until == null) return true;
    return _nowSec() >= until;
  }

  // ----- One-shot cold-boot URL (encrypted) -----
  Future<void> parkColdUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _crypt.delete(key: _keyColdUrl);
    } else {
      await _crypt.write(key: _keyColdUrl, value: url);
    }
  }

  Future<String?> consumeColdUrl() async {
    final String? url = await _crypt.read(key: _keyColdUrl);
    if (url != null) await _crypt.delete(key: _keyColdUrl);
    return url;
  }

  static int _nowSec() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
