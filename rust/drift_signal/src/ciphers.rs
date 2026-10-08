// ============================================================
//  Snowfall prism_core — layered symmetric codec
// ============================================================
//  Three XOR layers derived from embedded mantles. Nothing in
//  the compiled .so matches a plaintext substring; the only
//  bytes with structure are the per-slot ciphertexts in
//  sealed_data.rs. The mantles themselves are mixed through
//  FNV-1a and Murmur3 avalanche before any byte is emitted,
//  so a grep over strings(.so) returns noise.
// ============================================================

// ---- Mantle A (fuels the fnv keystream) --------------------
const MANTLE_A: &[u8] = &[
    0x1F, 0x82, 0x4E, 0xC7, 0xB1, 0x05, 0x6D, 0xAA,
    0x39, 0xCE, 0x92, 0x47, 0xFB, 0x08, 0x76, 0xD3,
    0x5C, 0x21, 0xEF, 0x8A, 0x43, 0xB9, 0x17, 0x6E,
];

// ---- Mantle B (fuels the murmur keystream) -----------------
const MANTLE_B: &[u8] = &[
    0xC2, 0x79, 0x16, 0xA4, 0x58, 0xDF, 0x03, 0xB7,
    0x6A, 0x1E, 0x8D, 0x45, 0xC9, 0x72, 0x30, 0xF8,
    0x5B, 0xE6, 0x24, 0x9F, 0x11, 0x87, 0xAC, 0x4D,
];

// ---- Mantle C (fuels the position-hash table) --------------
const MANTLE_C: &[u8] = &[
    0xE4, 0x1A, 0x7F, 0xB3, 0x08, 0x56, 0xDC, 0x29,
    0x4B, 0xA7, 0x15, 0x60, 0xCE, 0x82, 0x34, 0xF1,
    0x9D, 0x27, 0x68, 0xBE, 0x0C, 0x53, 0xA9, 0x7E,
];

// ---- FNV / Murmur primes -----------------------------------
const FNV_PRIME:  u32 = 0x0100_0193;
const FNV_SEED:   u32 = 0x811C_9DC5;
const MM_C1:      u32 = 0xCC9E_2D51;
const MM_C2:      u32 = 0x1B87_3593;
const MM_MIX_1:   u32 = 0x85EB_CA6B;
const MM_MIX_2:   u32 = 0xC2B2_AE35;

#[inline(always)]
fn fnv_fold(bytes: &[u8], extra: u32) -> u32 {
    let mut h: u32 = FNV_SEED ^ extra;
    let mut i = 0;
    while i < bytes.len() {
        h ^= bytes[i] as u32;
        h = h.wrapping_mul(FNV_PRIME);
        i += 1;
    }
    h
}

#[inline(always)]
fn murmur_mix(mut h: u32) -> u32 {
    h ^= h >> 16;
    h = h.wrapping_mul(MM_MIX_1);
    h ^= h >> 13;
    h = h.wrapping_mul(MM_MIX_2);
    h ^= h >> 16;
    h
}

#[inline(always)]
fn murmur_step(key: u32, seed: u32) -> u32 {
    let mut k = key.wrapping_mul(MM_C1);
    k = k.rotate_left(15);
    k = k.wrapping_mul(MM_C2);
    let mut h = seed ^ k;
    h = h.rotate_left(13);
    h.wrapping_mul(5).wrapping_add(0xE654_6B64)
}

// ---- Keystream byte generators ------------------------------
#[inline(never)]
fn ks_a(index: u32, salt_a: u16) -> u8 {
    // FNV-fold mantle A, mix with salted index.
    let base = fnv_fold(MANTLE_A, (salt_a as u32).wrapping_mul(0x9E37_79B1));
    let v = murmur_mix(base ^ index.wrapping_mul(0x27D4_EB2D));
    core::hint::black_box((v >> 11) as u8)
}

#[inline(never)]
fn ks_b(index: u32, salt_b: u16) -> u8 {
    // Murmur-step over mantle B treated as four 32-bit words.
    let mut h: u32 = (salt_b as u32).wrapping_mul(0x1656_67B1);
    let mut i = 0;
    while i + 4 <= MANTLE_B.len() {
        let word = (MANTLE_B[i] as u32)
            | ((MANTLE_B[i + 1] as u32) << 8)
            | ((MANTLE_B[i + 2] as u32) << 16)
            | ((MANTLE_B[i + 3] as u32) << 24);
        h = murmur_step(word, h);
        i += 4;
    }
    h = murmur_mix(h ^ index.wrapping_mul(0xA5A5_5A5A));
    core::hint::black_box((h >> 19) as u8)
}

#[inline(never)]
fn ks_pos(index: u32) -> u8 {
    // 64-entry position table derived from mantle C.
    // Rebuild on every call so the table never sits in .data.
    let seed = fnv_fold(MANTLE_C, 0x5A1E_C0DE);
    let mut acc = murmur_mix(seed.wrapping_add(index.wrapping_mul(0x1965_19E5)));
    acc ^= acc.rotate_left(7);
    acc = murmur_mix(acc);
    core::hint::black_box((acc >> 24) as u8)
}

// ---- Public codec (symmetric XOR of all three layers) ------
#[inline(never)]
pub(crate) fn transcode(cipher: &[u8], salt_a: u16, salt_b: u16) -> Vec<u8> {
    let mut out = Vec::with_capacity(cipher.len());
    let mut i: u32 = 0;
    for &c in cipher.iter() {
        let a = ks_a(i.wrapping_add(salt_a as u32), salt_a);
        let b = ks_b(i.wrapping_mul(0x9E37).wrapping_add(salt_b as u32), salt_b);
        let p = ks_pos(i ^ (salt_a as u32).wrapping_add(salt_b as u32));
        out.push(c ^ a ^ b ^ p);
        i = i.wrapping_add(1);
    }
    out
}

// ---- Dead-code jam (defeats trivial function fingerprinting) --
#[inline(never)]
#[allow(dead_code)]
pub(crate) fn __jam_a(x: u32) -> u32 {
    core::hint::black_box(fnv_fold(MANTLE_A, x) ^ murmur_mix(x))
}

#[inline(never)]
#[allow(dead_code)]
pub(crate) fn __jam_b(x: u32) -> u32 {
    core::hint::black_box(murmur_step(x, FNV_SEED).wrapping_add(ks_pos(x) as u32))
}
