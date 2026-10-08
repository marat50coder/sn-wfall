// Offline packer that mirrors lib/prism/codec/codec_mask.dart.
// Run once per secret change:
//   dart run tool/pack_seals.dart
//
// It prints a ready-to-paste `lib/prism/config/sealed_bytes.dart`
// to stdout. Nothing in `tool/` ever ships to the device.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const List<int> _mantle = <int>[
  0x4C, 0x1A, 0x97, 0x3B, 0xDE, 0x08, 0x61, 0xC4,
  0x75, 0xA2, 0x4F, 0x90, 0x12, 0xE5, 0x37, 0x8B,
  0xAD, 0x5E, 0x02, 0xF8,
];

const int _bandLength = 29;

Uint8List _band() {
  int acc = 0x811C9DC5;
  for (int i = 0; i < _mantle.length; i++) {
    acc ^= _mantle[i];
    acc = (acc * 0x01000193) & 0xFFFFFFFF;
  }
  if (acc == 0) acc = 0x6B79DEAD;
  final Uint8List b = Uint8List(_bandLength);
  for (int i = 0; i < _bandLength; i++) {
    int h = acc ^ (i * 0xCC9E2D51);
    h ^= h >> 16;
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
    h ^= h >> 16;
    b[i] = (h >> 8) & 0xFF;
    acc = (acc + 0xA5A5A5A5 + i) & 0xFFFFFFFF;
  }
  return b;
}

int _positionTint(int index) {
  int h = index * 0x27D4EB2D;
  h ^= h >> 15;
  h = (h * 0x165667B1) & 0xFFFFFFFF;
  h ^= h >> 13;
  return (h >> 8) & 0xFF;
}

final Uint8List _bandCache = _band();

List<int> _conceal(String plain) {
  final List<int> raw = utf8.encode(plain);
  final List<int> out = List<int>.filled(raw.length, 0);
  for (int i = 0; i < raw.length; i++) {
    out[i] = (raw[i] ^ _bandCache[i % _bandLength] ^ _positionTint(i)) & 0xFF;
  }
  return out;
}

String _concealLiteral(String plain) {
  // Pretty-print a 12-column hex literal list.
  final List<int> bytes = _conceal(plain);
  if (bytes.isEmpty) return '<int>[]';
  final StringBuffer buf = StringBuffer('<int>[\n');
  for (int i = 0; i < bytes.length; i++) {
    if (i % 12 == 0) buf.write('      ');
    buf.write('0x${bytes[i].toRadixString(16).padLeft(2, '0')}, ');
    if (i % 12 == 11) buf.write('\n');
  }
  if (bytes.length % 12 != 0) buf.write('\n');
  buf.write('    ]');
  return buf.toString();
}

// ----------------------------------------------------------
// Sealed values — plaintext source of truth
// ----------------------------------------------------------
final Map<String, String> _slots = <String, String>{
  // Verdict endpoint (dirty partner URL, intentionally kept opaque).
  'verdictEndpoint': 'https://snowfallodysseyy.com/config.php',

  // AppsFlyer dev key for this app.
  'attributionKey': 'UhoQg2ZmjMkBbqyrGeV6Hi',

  // AppsFlyer GCD base — same across siblings, host is AppsFlyer's.
  'gcdBase': 'https://gcdsdk.appsflyer.com/install_data/v4.0/',

  // Firebase project number (from google-services.json).
  'messagingProject': '809716520665',

  // UA scaffolding — identical plaintext as a real Chrome Android.
  'uaProduct': 'Mozilla/5.0',
  'uaLinuxOpen': '(Linux; Android',
  'uaBuildLabel': ' Build/',
  'uaBuildClose': ')',
  'uaEngineLabel': ' AppleWebKit/',
  'uaEngineTail': ' (KHTML, like Gecko)',
  'uaChromeLabel': ' Chrome/',
  'uaMobileSafari': ' Mobile Safari/',

  // Slot-game identity suffix (appid/<bundle> appname/<AppName>).
  'uaAppIdToken': 'appid/',
  'uaAppNameToken': 'appname/',
  'uaAppName': 'SnowfallOdyssey',

  // Chrome version — rotated per project.
  'chromeVersion': '149.0.7823.137',
  'webkitVersion': '537.36',

  // JS enhancer bodies — safe-area override + keyboard refocus +
  // autoplay unlock. Hand-written for Snowfall (different control
  // flow + sentinel from the template).
  'jsSafeArea':
      '(function(){'
      'if(window.__snfSafe)return;window.__snfSafe=1;'
      'var s=document.createElement("style");'
      's.textContent=":root{"'
      '+ "--safe-area-inset-top:0px!important;"'
      '+ "--safe-area-inset-right:0px!important;"'
      '+ "--safe-area-inset-bottom:0px!important;"'
      '+ "--safe-area-inset-left:0px!important;"'
      '+ "--sat:0px!important;--sar:0px!important;"'
      '+ "--sab:0px!important;--sal:0px!important;"'
      '+ "--safe-top:0px!important;--safe-bottom:0px!important;"'
      '+ "--safe-left:0px!important;--safe-right:0px!important;}"'
      '+ ".gameview-mobile-header,.app-header,.js-safe-top{"'
      '+ "padding-top:0!important;margin-top:0!important;}";'
      'document.documentElement.appendChild(s);'
      '})();',

  'jsKeyboard':
      '(function(){'
      'if(window.__snfKbd)return;window.__snfKbd=1;'
      'var pull=function(ev){'
      'var t=ev && ev.target;'
      'if(!t||t.tagName!=="INPUT"&&t.tagName!=="TEXTAREA")return;'
      'setTimeout(function(){try{'
      't.scrollIntoView({block:"center",behavior:"smooth"});'
      '}catch(_){}' ', 220);'
      '};'
      'document.addEventListener("focusin",pull,true);'
      '})();',

  'jsAutoplay':
      '(function(){'
      'if(window.__snfAp)return;window.__snfAp=1;'
      'var tap=function(){'
      'var vs=document.querySelectorAll("video");'
      'for(var i=0;i<vs.length;i++){'
      'var v=vs[i];try{v.muted=true;v.playsInline=true;'
      'var p=v.play();if(p&&p.catch)p.catch(function(){});}'
      'catch(_){}' '}'
      '};'
      'document.addEventListener("DOMContentLoaded",tap);'
      'window.setTimeout(tap,1200);'
      '})();',
};

void main() {
  final StringBuffer out = StringBuffer();
  out.writeln("// ============================================================");
  out.writeln("// AUTO-GENERATED by tool/pack_seals.dart. Do not hand-edit.");
  out.writeln("// Change the plaintexts there, re-run, paste the output here.");
  out.writeln("// ============================================================");
  out.writeln("");
  out.writeln("import '../codec/codec_mask.dart';");
  out.writeln("");

  _slots.forEach((String name, String plain) {
    out.writeln('const List<int> _$name = ${_concealLiteral(plain)};');
    out.writeln('');
  });

  // Public accessors
  _slots.forEach((String name, String plain) {
    final String capped = name[0].toUpperCase() + name.substring(1);
    out.writeln('String unmask$capped() => unmask(_$name);');
  });

  out.writeln('');
  out.writeln('String unmaskGcdCallUrl(String appId, String deviceId) {');
  out.writeln('  final String base = unmaskGcdBase();');
  out.writeln('  if (base.isEmpty) return "";');
  out.writeln('  return "\$base\$appId?devkey=\${unmaskAttributionKey()}&device_id=\$deviceId";');
  out.writeln('}');

  // Round-trip sanity check.
  _slots.forEach((String name, String plain) {
    final List<int> bytes = _conceal(plain);
    final String back = _reveal(bytes);
    if (back != plain) {
      stderr.writeln('ROUND-TRIP FAIL at $name');
      exitCode = 1;
    }
  });

  stdout.write(out.toString());
}

String _reveal(List<int> sealed) {
  if (sealed.isEmpty) return '';
  final Uint8List plain = Uint8List(sealed.length);
  for (int i = 0; i < sealed.length; i++) {
    plain[i] = (sealed[i] ^ _bandCache[i % _bandLength] ^ _positionTint(i)) & 0xFF;
  }
  return utf8.decode(plain, allowMalformed: true);
}
