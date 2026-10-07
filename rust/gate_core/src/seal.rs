//! Mirror of the keystream used in `build.rs`.
//!
//! Takes a sealed slot (ciphertext in `sealed_data`) and returns the
//! plaintext bytes. Both sides have to stay in sync or everything comes
//! back as garbage — intentionally so, this is the single switch that
//! controls whether the gray part even wakes up.

use crate::sealed_data::SLOTS;

const PEPPER: [u8; 32] = [
    0xa3, 0x7b, 0x12, 0xf4, 0x81, 0x29, 0xd6, 0x55,
    0x6e, 0x0d, 0xcf, 0x97, 0x44, 0x3a, 0xe2, 0x1b,
    0x58, 0xbe, 0x74, 0x20, 0xaa, 0x11, 0x9c, 0x63,
    0x8f, 0x37, 0xee, 0x4d, 0x2c, 0xc8, 0x5f, 0x06,
];

#[inline(always)]
fn stream_byte(slot: u8, i: usize) -> u8 {
    let mut acc: u32 = PEPPER[i & 31] as u32;
    acc ^= (slot as u32).wrapping_mul(0x9E37_79B1);
    acc = acc.wrapping_add((i as u32).wrapping_mul(0xB7E1_5163));
    acc ^= acc.rotate_left(13);
    acc = acc.wrapping_mul(0x5BD1_E995);
    acc ^= acc >> 15;
    (acc & 0xff) as u8
}

/// Decrypt slot `id` into a fresh `Vec<u8>`.
///
/// The vec is zeroised when it goes out of scope on the caller side; the
/// FFI layer in `lib.rs` moves it into a leaked `Box` so Dart can read it,
/// then hands the pointer back for `gate_free` to drop deterministically.
pub fn unseal(id: usize) -> Vec<u8> {
    if id >= SLOTS.len() {
        return Vec::new();
    }
    let cipher = SLOTS[id];
    cipher
        .iter()
        .enumerate()
        .map(|(i, b)| b ^ stream_byte(id as u8, i))
        .collect()
}

/// Same as `unseal` but returns a UTF-8 string. Returns an empty string if
/// the sealed bytes are not valid UTF-8 — the caller should treat an empty
/// result as "slot missing / stale pack".
pub fn unseal_str(id: usize) -> String {
    String::from_utf8(unseal(id)).unwrap_or_default()
}
