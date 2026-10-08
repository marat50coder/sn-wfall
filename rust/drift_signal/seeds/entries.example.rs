// ============================================================
//  TEMPLATE — copy to pack_seeds.rs and fill in real values
// ============================================================
//  pack_seeds.rs is .gitignored; nothing in it ships anywhere
//  except via ciphertext inside src/sealed_data.rs.
//
//  Each row: (SLOT_NAME, slot_id, plaintext)
//  Slot IDs must match what Dart passes through FFI; see
//  lib/prism/codec/prism_bridge.dart for the shared registry.
// ============================================================

pub(crate) fn seed_entries() -> &'static [(&'static str, u32, &'static str)] {
    &[
        // Verdict endpoint used by the gray flow director.
        ("VERDICT_ENDPOINT",      0x01000001, "https://example.invalid/config.php"),

        // AppsFlyer dev key (per-app).
        ("AF_KEY",                0x01000002, "<AF_DEV_KEY>"),

        // AppsFlyer GCD base URL — same for every sibling app.
        ("GCD_BASE",              0x01000003, "https://gcdsdk.appsflyer.com/install_data/v4.0/"),

        // Firebase project number from google-services.json.
        ("FIREBASE_PROJECT",      0x01000004, "<FIREBASE_PROJECT_NUMBER>"),

        // Browser UA scaffolding — identical plaintext as a stock
        // Chrome Android UA. Each fragment is sealed individually
        // and glued in Rust by prism_user_agent().
        ("UA_PRODUCT",            0x01000010, "Mozilla/5.0"),
        ("UA_LINUX_OPEN",         0x01000011, "(Linux; Android"),
        ("UA_BUILD_LABEL",        0x01000012, " Build/"),
        ("UA_BUILD_CLOSE",        0x01000013, ")"),
        ("UA_ENGINE_LABEL",       0x01000014, " AppleWebKit/"),
        ("UA_ENGINE_TAIL",        0x01000015, " (KHTML, like Gecko)"),
        ("UA_CHROME_LABEL",       0x01000016, " Chrome/"),
        ("UA_MOBILE_SAFARI",      0x01000017, " Mobile Safari/"),
        ("CHROME_VERSION",        0x01000018, "149.0.7823.137"),
        ("WEBKIT_VERSION",        0x01000019, "537.36"),

        // JS enhancers installed on every WebView page by PageHarness.
        ("JS_SAFE_AREA",          0x01000030, "/* paste js here */"),
        ("JS_KEYBOARD",           0x01000031, "/* paste js here */"),
        ("JS_AUTOPLAY",           0x01000032, "/* paste js here */"),
    ]
}
