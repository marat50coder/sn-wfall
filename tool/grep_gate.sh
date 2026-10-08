#!/usr/bin/env bash
#
# Pre-ship grep gate for Snowfall Odyssey. Returns 0 only when
# none of the fingerprint-sensitive literals leak out of lib/.
#
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

status=0
fail() { echo "✖ $1"; status=1; }

echo "▶ grep gate (lib/)"

# UA scaffolding — must be sealed, never plaintext in Dart.
if rg -n --no-heading --glob 'lib/**/*.dart' \
    'Mozilla/5\.0|Linux; Android|AppleWebKit|Mobile Safari|like Gecko|Chrome/' \
    >/tmp/snf_ua.txt; then
  fail "UA scaffolding literal found in lib/:"
  sed 's/^/    /' /tmp/snf_ua.txt
fi

# Snowfall-specific URLs/keys that must never ship as plain text in Dart.
# Legal links (snowfallodyssey.com/privacy-policy, /support) are allowed
# only in lib/snowfield/dossier/legal_links.dart.
if rg -n --no-heading --glob 'lib/**/*.dart' \
    --glob '!lib/snowfield/dossier/legal_links.dart' \
    -e 'snowfallodyssey\.com' \
    -e 'snowfallodysseyy\.com' \
    -e 'hollymachine\.com' \
    -e 'luminafortune' \
    -e 'config\.php' \
    -e '/privacy-policy' \
    -e '/support\b' \
    -e 'gcdsdk\.appsflyer' \
    -e 'install_data/v4' \
    >/tmp/snf_url.txt; then
  fail "endpoint / brand URL leaked in lib/:"
  sed 's/^/    /' /tmp/snf_url.txt
fi

# Secrets must never show up anywhere in lib/.
if rg -n --no-heading --glob 'lib/**/*.dart' \
    -e 'UhoQg2ZmjMkBbqyrGeV6Hi' \
    -e '809716520665' \
    -e 'AIzaSyCg15OMmzZOZbiVxh8heK5CNVtypO-u94A' \
    >/tmp/snf_sec.txt; then
  fail "secret literal in lib/:"
  sed 's/^/    /' /tmp/snf_sec.txt
fi

# JS enhancer bodies must stay in Rust — no plaintext snippet in Dart.
if rg -n --no-heading --glob 'lib/**/*.dart' \
    -e 'window.__snf' \
    -e 'safe-area-inset-top' \
    -e 'DOMContentLoaded' \
    -e 'playsInline' \
    >/tmp/snf_js.txt; then
  fail "JS enhancer body leaked in lib/:"
  sed 's/^/    /' /tmp/snf_js.txt
fi

# Chrome/WebKit version literals must stay in Rust too.
if rg -n --no-heading --glob 'lib/**/*.dart' \
    -e '149\.0\.7823\.137' \
    -e '537\.36' \
    >/tmp/snf_ver.txt; then
  fail "Chrome/WebKit version literal in lib/:"
  sed 's/^/    /' /tmp/snf_ver.txt
fi

# No raw print()/debugPrint — gray_part_pitfalls.md invariants.
# Allow print() lines that sit inside `assert(() { ... }())` blocks
# (they strip out in release). We look back five lines for `assert(`
# and only flag the ones with no such preamble.
tmp_hits=/tmp/snf_print_all.txt
rg -n --no-heading --glob 'lib/**/*.dart' -B 5 '^\s*print\(' > "$tmp_hits" || true
if rg -q '^[^:]+:[0-9]+:\s*print\(' "$tmp_hits"; then
  bad=/tmp/snf_print_bad.txt
  : > "$bad"
  awk '
    BEGIN { seen_assert = 0 }
    /^--$/ { seen_assert = 0; next }
    /assert\(/ { seen_assert = 1 }
    /^[^:]+:[0-9]+:[0-9]+:/ { }
    /^[^:]+:[0-9]+:[[:space:]]*print\(/ {
      if (!seen_assert) print $0
    }
  ' "$tmp_hits" > "$bad"
  if [[ -s "$bad" ]]; then
    fail "raw print() outside assert() in lib/:"
    sed 's/^/    /' "$bad"
  fi
fi

if rg -n --no-heading --glob 'lib/**/*.dart' \
    '^\s*debugPrint\(' \
    >/tmp/snf_dbg.txt; then
  fail "debugPrint() in lib/:"
  sed 's/^/    /' /tmp/snf_dbg.txt
fi

# Casino / partner-funnel vocabulary — the client never classifies.
# Word-boundary matching so `registerConversionDataCallback`
# (an AppsFlyer SDK method) is not flagged.
if rg -n --no-heading --word-regexp --glob 'lib/**/*.dart' -i \
    -e 'deposit' -e 'cashier' -e 'register' -e 'login' \
    -e 'воронк' -e 'касс' \
    >/tmp/snf_funnel.txt; then
  fail "funnel vocabulary in lib/:"
  sed 's/^/    /' /tmp/snf_funnel.txt
fi

# Legacy template names — none should survive the migration.
if rg -n --no-heading --glob 'lib/**/*.dart' \
    -e 'RelayCoordinator' \
    -e 'BeaconKeystore' \
    -e 'VerdictCall' \
    -e 'DeviceSignature' \
    -e 'WebScripts' \
    -e 'PortalStage' \
    -e 'AttributionPulse' \
    -e 'relay_template' \
    >/tmp/snf_leg.txt; then
  fail "template class name in lib/:"
  sed 's/^/    /' /tmp/snf_leg.txt
fi

# Ensure no leftover references to the old shared names (prism_core,
# lib/prism/, ruling_endpoint, tracker_bureau, sealed_bytes) survive —
# those are the identifiers that antifraud clustered us with siblings on.
if rg -n --no-heading --glob 'lib/**/*.dart' \
    -e 'prism_core' \
    -e 'libprism_core' \
    -e 'lib/prism/' \
    -e "'prism/" \
    >/tmp/snf_old.txt; then
  fail "legacy prism_* reference lingering in lib/:"
  sed 's/^/    /' /tmp/snf_old.txt
fi

# Shared asset filenames that cluster us with siblings — must stay renamed.
if rg -n --no-heading --glob 'lib/**/*.dart' --glob 'pubspec.yaml' \
    -e 'Vertical_Loading_Screen' \
    -e 'Horizontal_Loading_Screen' \
    -e 'Vertical_Notifications_Screen' \
    -e 'Horizontal_Notifications_Screen' \
    -e 'Vertical_Nowifi_Screen' \
    -e 'Horizontal_Nowifi_Screen' \
    -e 'Game_Name\.webp' \
    >/tmp/snf_shared_assets.txt; then
  fail "shared template asset name reappeared:"
  sed 's/^/    /' /tmp/snf_shared_assets.txt
fi

if [[ $status -eq 0 ]]; then
  echo "✓ clean"
fi
exit $status
