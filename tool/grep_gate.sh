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
# via lib/prism/config/legal_links.dart.
if rg -n --no-heading --glob 'lib/**/*.dart' \
    --glob '!lib/prism/config/legal_links.dart' \
    -e 'snowfallodyssey\.com' \
    -e 'snowfallodysseyy\.com' \
    -e 'config\.php' \
    -e '/privacy-policy' \
    -e '/support\b' \
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

if [[ $status -eq 0 ]]; then
  echo "✓ clean"
fi
exit $status
