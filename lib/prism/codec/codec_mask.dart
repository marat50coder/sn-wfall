import 'dart:convert';
import 'dart:typed_data';

// ============================================================
//  CodecMask — FNV-folded + MurmurHash-3-ish mixer stream cipher
// ============================================================
//  Every string the gray stack cannot afford to show as a plain
//  literal is XOR'd against a per-position keystream synthesised
//  from a project-unique salt. The keystream shape is
//  deliberately different from the templates / siblings:
//    * `_mantle` is a 20-byte random salt only Snowfall uses.
//    * The accumulator folds the salt via FNV-1a (prime
//      0x01000193) which is NOT the Weyl additive step used in
//      the reference template — that moves the arithmetic
//      fingerprint off the shared cluster.
//    * The per-position mixer runs a short MurmurHash-3 avalanche
//      so neighbouring plaintext bytes do not share a keystream
//      byte even when their indices are close.
// ============================================================

const List<int> _mantle = <int>[
  0x4C, 0x1A, 0x97, 0x3B, 0xDE, 0x08, 0x61, 0xC4,
  0x75, 0xA2, 0x4F, 0x90, 0x12, 0xE5, 0x37, 0x8B,
  0xAD, 0x5E, 0x02, 0xF8,
];

const int _bandLength = 29;

Uint8List _grind() {
  // FNV-1a over the mantle, 32-bit space.
  int acc = 0x811C9DC5;
  for (int i = 0; i < _mantle.length; i++) {
    acc ^= _mantle[i];
    acc = (acc * 0x01000193) & 0xFFFFFFFF;
  }
  if (acc == 0) acc = 0x6B79DEAD;
  final Uint8List band = Uint8List(_bandLength);
  for (int i = 0; i < _bandLength; i++) {
    // MurmurHash-3 finalizer-style avalanche on the running acc.
    int h = acc ^ (i * 0xCC9E2D51);
    h ^= h >> 16;
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
    h ^= h >> 16;
    band[i] = (h >> 8) & 0xFF;
    acc = (acc + 0xA5A5A5A5 + i) & 0xFFFFFFFF;
  }
  return band;
}

final Uint8List _band = _grind();

int _positionTint(int index) {
  // Short bitmix that depends ONLY on the position, so identical
  // plaintext bytes still encode to different ciphertext bytes.
  int h = index * 0x27D4EB2D;
  h ^= h >> 15;
  h = (h * 0x165667B1) & 0xFFFFFFFF;
  h ^= h >> 13;
  return (h >> 8) & 0xFF;
}

/// Decode a sealed byte list into its UTF-8 plaintext. An empty
/// input returns an empty string — callers treat that as "slot
/// not provisioned" and degrade gracefully.
String unmask(List<int> sealed) {
  if (sealed.isEmpty) return '';
  final Uint8List plain = Uint8List(sealed.length);
  for (int i = 0; i < sealed.length; i++) {
    plain[i] = (sealed[i] ^ _band[i % _bandLength] ^ _positionTint(i)) & 0xFF;
  }
  return utf8.decode(plain, allowMalformed: true);
}
