// ============================================================
//  ColdBeacon — thin one-shot cold-boot URL reader
// ============================================================
//  A cold-boot push tap on Android delivers the URL through the
//  launch intent, which Firebase Messaging surfaces via
//  getInitialMessage(). SignalRelay writes it into the vault's
//  cold-url slot; this helper is the single read site so the
//  director has a symmetric API for cold and warm launches.
// ============================================================

import 'aurora_vault.dart';

class ColdBeacon {
  ColdBeacon._();

  /// Read and clear the cold-boot URL. Returns null when none.
  static Future<String?> consume(AuroraVault vault) =>
      vault.consumeColdUrl();
}
