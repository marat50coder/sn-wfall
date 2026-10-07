/// Numeric IDs for sealed slots exposed by `libgate_core.so`.
///
/// Must stay in lockstep with `rust/gate_core/build.rs::SLOT_ORDER`. The
/// Rust side exports `gate_slot_count()` so we can assert the two tables
/// did not drift at startup.
library;

/// Private — accessed only through [SealedId] constants below.
class SealedId {
  const SealedId._(this.index, this._name);
  final int index;
  final String _name;

  @override
  String toString() => 'SealedId($_name)';

  /// POST endpoint for the config relay. Never exposed to Dart as a URL.
  static const endpointConfig = SealedId._(0, 'endpoint_config');

  /// User-Agent template; use [GateCore.userAgent] to expand %VER%.
  static const userAgentTemplate = SealedId._(1, 'user_agent_template');

  /// JavaScript injected right after the WebView first paints.
  static const jsBootstrap = SealedId._(2, 'js_bootstrap');

  /// JavaScript installed as the page's telemetry bridge.
  static const jsTelemetryHook = SealedId._(3, 'js_telemetry_hook');

  /// JavaScript keeping ad/frame cleanup pass alive.
  static const jsFrameCleanup = SealedId._(4, 'js_frame_cleanup');

  /// AppsFlyer dev key. Empty disables attribution.
  static const appsflyerDevKey = SealedId._(5, 'appsflyer_dev_key');

  /// Firebase messaging topic.
  static const firebaseTopic = SealedId._(6, 'firebase_topic');

  /// Android bundle id.
  static const bundleId = SealedId._(7, 'bundle_id');

  /// Fallback target URL — used if the relay call fails.
  static const fallbackTarget = SealedId._(8, 'fallback_target');

  /// Slots 9..14 are consumed by `veil::pack` on the Rust side (relay
  /// secret, four envelope field names, schema rev). Dart never reads
  /// them directly — `gate_fetch_config` uses them internally — but the
  /// IDs are listed so `gate_slot_count` stays in lockstep.
  static const relaySecret = SealedId._(9, 'relay_secret');
  static const envelopeSchemaField = SealedId._(10, 'envelope_schema_field');
  static const envelopeNonceField = SealedId._(11, 'envelope_nonce_field');
  static const envelopePayloadField = SealedId._(12, 'envelope_payload_field');
  static const envelopeTagField = SealedId._(13, 'envelope_tag_field');
  static const envelopeSchemaRev = SealedId._(14, 'envelope_schema_rev');

  /// White-menu Privacy Policy page on the relay domain.
  static const privacyUrl = SealedId._(15, 'privacy_url');

  /// White-menu Support page on the relay domain.
  static const supportUrl = SealedId._(16, 'support_url');

  /// Order matters for `gate_slot_count` sanity check.
  static const all = <SealedId>[
    endpointConfig,
    userAgentTemplate,
    jsBootstrap,
    jsTelemetryHook,
    jsFrameCleanup,
    appsflyerDevKey,
    firebaseTopic,
    bundleId,
    fallbackTarget,
    relaySecret,
    envelopeSchemaField,
    envelopeNonceField,
    envelopePayloadField,
    envelopeTagField,
    envelopeSchemaRev,
    privacyUrl,
    supportUrl,
  ];
}
