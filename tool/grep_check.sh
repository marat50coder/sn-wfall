#!/usr/bin/env bash
#
# Final grep gate for the gray-part audit.
#
# Walks `lib/` and flags any plaintext literal that would let an attacker
# bypass the Rust seal (URL, bundle id, UA fragment, config path, dev key).
# Also catches raw `print()` calls that could leak decrypted data into
# logcat on a release build.
#
# Exits with 0 when the tree is clean, 1 on any finding.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

status=0
fail() {
  echo "✖ $1"
  status=1
}

echo "▶ grep gate (lib/)"

# 1. No http:// or https:// hardcoded.
if rg -n --no-heading --glob 'lib/**/*.dart' 'https?://' >/tmp/gate_http.txt; then
  fail "http(s):// literal found in lib/:"
  sed 's/^/    /' /tmp/gate_http.txt
fi

# 2. No reference to the config endpoint or the brand domain.
if rg -n --no-heading --glob 'lib/**/*.dart' -i 'snowfallodyssey|config\.php|\.site/|/privacy-policy|/support\.html' >/tmp/gate_brand.txt; then
  fail "brand/endpoint literal found in lib/:"
  sed 's/^/    /' /tmp/gate_brand.txt
fi

# 3. No raw bundle id outside the Rust bridge comments.
if rg -n --no-heading --glob 'lib/**/*.dart' 'com\.snowfallodyssey' >/tmp/gate_bundle.txt; then
  fail "bundle id leaked in lib/:"
  sed 's/^/    /' /tmp/gate_bundle.txt
fi

# 4. No User-Agent fragment hardcoded.
if rg -n --no-heading --glob 'lib/**/*.dart' -i 'Mozilla/|AppleWebKit|GAME THEME CATEGORY|appid//appname/' >/tmp/gate_ua.txt; then
  fail "User-Agent fragment in lib/:"
  sed 's/^/    /' /tmp/gate_ua.txt
fi

# 5. No AppsFlyer dev key or Firebase topic value in Dart. The slot
#    *identifier* (`appsflyer_dev_key`) is allowed in sealed_ids.dart since
#    it is just an index name, not the key itself.
if rg -n --no-heading --glob 'lib/**/*.dart' --glob '!lib/gate/sealed_ids.dart' 'devkey=|dev_key|messaging/topics|appsflyer' >/tmp/gate_keys.txt; then
  fail "attribution/push literal in lib/:"
  sed 's/^/    /' /tmp/gate_keys.txt
fi

# 6. No unguarded `print(` — every print has to be inside `kDebugMode`
#    (via `debugLog(() => …)` helper in `gate_service.dart`).
if rg -n --no-heading --glob 'lib/**/*.dart' --glob '!lib/gate/gate_service.dart' '^\s*print\(' >/tmp/gate_print.txt; then
  fail "raw print() outside gate_service.dart:"
  sed 's/^/    /' /tmp/gate_print.txt
fi

# 7. Prism/old-style config helpers must be gone.
if rg -n --no-heading --glob 'lib/**/*.dart' -i 'prism_pack|ruling_endpoint|tracker_bureau|sealed_bytes' >/tmp/gate_old.txt; then
  fail "legacy prism helpers still present:"
  sed 's/^/    /' /tmp/gate_old.txt
fi

if [[ $status -eq 0 ]]; then
  echo "✓ clean"
fi
exit $status
