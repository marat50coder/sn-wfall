import 'package:webview_flutter/webview_flutter.dart';

import '../config/sealed_bytes.dart';

// ============================================================
//  PageHarness — ordered JS enhancer injection
// ============================================================
//  Every body lives sealed in sealed_bytes.dart. Each enhancer
//  guards itself with a Snowfall-specific window sentinel
//  (`__snfSafe`, `__snfKbd`, `__snfAp`) so calling installAll
//  on every onPageFinished is idempotent. See
//  webview_safe_area_injection.mdc for the exact invariants —
//  the safe-area body here only touches CSS variables and the
//  narrow decorative header classes, never html / body / #app.
// ============================================================

class PageHarness {
  PageHarness._();

  static Future<void> installAll(WebViewController controller) async {
    for (final String body in _bodies()) {
      if (body.isEmpty) continue;
      try {
        await controller.runJavaScript(body);
      } catch (_) {
        // A single enhancer failing must not kill the WebView.
      }
    }
  }

  static List<String> _bodies() => <String>[
        unmaskJsSafeArea(),
        unmaskJsKeyboard(),
        unmaskJsAutoplay(),
      ];
}
