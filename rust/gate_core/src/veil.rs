//! Opaque envelope pack for the edge-relay.
//!
//! Mirrors `scripts/relay_service.py::unpack` byte for byte: the server
//! unpacks what we pack here with the per-app secret and envelope field
//! names (both are sealed in `sealed/seed.toml`).
//!
//!   raw      = utf8( json(body, compact) )
//!   nonce    = 16 random bytes
//!   stream_i = sha256(secret || nonce || be32(i))
//!   enc      = raw XOR stream
//!   payload  = base64url(enc) without padding
//!   tag      = hex( HMAC-SHA256(secret, nonce || enc) )[:16]
//!
//! The final envelope is a tiny JSON object with four fields whose keys
//! are also sealed, so the on-wire fingerprint differs per app.

use std::time::{SystemTime, UNIX_EPOCH};

use crate::seal;

// Hand-rolled sha256/hmac/base64 so the crate stays dependency-light and
// nothing shows up in the binary's symbol table as "sha2" / "hmac" / etc.
mod primitives {
    const K: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
        0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
        0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
        0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
        0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    pub fn sha256(data: &[u8]) -> [u8; 32] {
        let mut h = [
            0x6a09e667u32, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        ];
        let bit_len = (data.len() as u64).wrapping_mul(8);
        let mut buf = Vec::with_capacity(data.len() + 72);
        buf.extend_from_slice(data);
        buf.push(0x80);
        while buf.len() % 64 != 56 {
            buf.push(0);
        }
        buf.extend_from_slice(&bit_len.to_be_bytes());

        for chunk in buf.chunks(64) {
            let mut w = [0u32; 64];
            for i in 0..16 {
                w[i] = u32::from_be_bytes([
                    chunk[4 * i], chunk[4 * i + 1],
                    chunk[4 * i + 2], chunk[4 * i + 3],
                ]);
            }
            for i in 16..64 {
                let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
                let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
                w[i] = w[i - 16]
                    .wrapping_add(s0)
                    .wrapping_add(w[i - 7])
                    .wrapping_add(s1);
            }
            let (mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut hh) =
                (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]);
            for i in 0..64 {
                let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
                let ch = (e & f) ^ (!e & g);
                let t1 = hh.wrapping_add(s1).wrapping_add(ch).wrapping_add(K[i]).wrapping_add(w[i]);
                let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
                let mj = (a & b) ^ (a & c) ^ (b & c);
                let t2 = s0.wrapping_add(mj);
                hh = g;
                g = f;
                f = e;
                e = d.wrapping_add(t1);
                d = c;
                c = b;
                b = a;
                a = t1.wrapping_add(t2);
            }
            h[0] = h[0].wrapping_add(a);
            h[1] = h[1].wrapping_add(b);
            h[2] = h[2].wrapping_add(c);
            h[3] = h[3].wrapping_add(d);
            h[4] = h[4].wrapping_add(e);
            h[5] = h[5].wrapping_add(f);
            h[6] = h[6].wrapping_add(g);
            h[7] = h[7].wrapping_add(hh);
        }
        let mut out = [0u8; 32];
        for i in 0..8 {
            out[4 * i..4 * i + 4].copy_from_slice(&h[i].to_be_bytes());
        }
        out
    }

    pub fn hmac_sha256(key: &[u8], msg: &[u8]) -> [u8; 32] {
        let mut k = [0u8; 64];
        if key.len() > 64 {
            k[..32].copy_from_slice(&sha256(key));
        } else {
            k[..key.len()].copy_from_slice(key);
        }
        let mut ipad = [0u8; 64];
        let mut opad = [0u8; 64];
        for i in 0..64 {
            ipad[i] = k[i] ^ 0x36;
            opad[i] = k[i] ^ 0x5c;
        }
        let mut inner = Vec::with_capacity(64 + msg.len());
        inner.extend_from_slice(&ipad);
        inner.extend_from_slice(msg);
        let ih = sha256(&inner);
        let mut outer = Vec::with_capacity(96);
        outer.extend_from_slice(&opad);
        outer.extend_from_slice(&ih);
        sha256(&outer)
    }

    const B64: &[u8; 64] =
        b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

    pub fn base64url_nopad(src: &[u8]) -> String {
        let mut out = Vec::with_capacity(src.len() * 4 / 3 + 4);
        let mut i = 0;
        while i + 3 <= src.len() {
            let n = ((src[i] as u32) << 16) | ((src[i + 1] as u32) << 8) | (src[i + 2] as u32);
            out.push(B64[((n >> 18) & 0x3f) as usize]);
            out.push(B64[((n >> 12) & 0x3f) as usize]);
            out.push(B64[((n >> 6) & 0x3f) as usize]);
            out.push(B64[(n & 0x3f) as usize]);
            i += 3;
        }
        let rem = src.len() - i;
        if rem == 1 {
            let n = (src[i] as u32) << 16;
            out.push(B64[((n >> 18) & 0x3f) as usize]);
            out.push(B64[((n >> 12) & 0x3f) as usize]);
        } else if rem == 2 {
            let n = ((src[i] as u32) << 16) | ((src[i + 1] as u32) << 8);
            out.push(B64[((n >> 18) & 0x3f) as usize]);
            out.push(B64[((n >> 12) & 0x3f) as usize]);
            out.push(B64[((n >> 6) & 0x3f) as usize]);
        }
        String::from_utf8(out).unwrap()
    }

    pub fn hex(src: &[u8]) -> String {
        let mut out = String::with_capacity(src.len() * 2);
        for b in src {
            let hi = b >> 4;
            let lo = b & 0x0f;
            out.push(if hi < 10 { (b'0' + hi) as char } else { (b'a' + hi - 10) as char });
            out.push(if lo < 10 { (b'0' + lo) as char } else { (b'a' + lo - 10) as char });
        }
        out
    }
}

/// Mix-up PRNG used to generate the 16-byte envelope nonce. We can't link
/// `getrandom` on android easily without extra features, and the nonce
/// doesn't have to be cryptographically secret — only unique per request.
fn nonce16() -> [u8; 16] {
    let seed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(0xdead_beef_cafe_babe);
    let mut state = seed ^ 0x9E3779B97F4A7C15u64;
    let mut out = [0u8; 16];
    for chunk in out.chunks_mut(8) {
        // xorshift64
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        chunk.copy_from_slice(&state.to_le_bytes()[..chunk.len()]);
    }
    out
}

fn keystream(secret: &[u8], nonce: &[u8], length: usize) -> Vec<u8> {
    let mut out = Vec::with_capacity(length + 32);
    let mut counter: u32 = 0;
    while out.len() < length {
        let mut buf = Vec::with_capacity(secret.len() + nonce.len() + 4);
        buf.extend_from_slice(secret);
        buf.extend_from_slice(nonce);
        buf.extend_from_slice(&counter.to_be_bytes());
        out.extend_from_slice(&primitives::sha256(&buf));
        counter = counter.wrapping_add(1);
    }
    out.truncate(length);
    out
}

/// Build the envelope JSON. Returns an empty string if the sealed secret
/// or any of the sealed field names is missing — the caller treats that
/// as "stay on the white part".
pub fn pack(payload_json: &[u8]) -> String {
    let secret = seal::unseal_str(9);
    let f_schema = seal::unseal_str(10);
    let f_nonce = seal::unseal_str(11);
    let f_payload = seal::unseal_str(12);
    let f_tag = seal::unseal_str(13);
    let rev_s = seal::unseal_str(14);
    if secret.is_empty()
        || f_schema.is_empty()
        || f_nonce.is_empty()
        || f_payload.is_empty()
        || f_tag.is_empty()
        || rev_s.is_empty()
    {
        return String::new();
    }
    let rev: u32 = rev_s.parse().unwrap_or(0);

    let secret_bytes = secret.as_bytes();
    let nonce = nonce16();
    let stream = keystream(secret_bytes, &nonce, payload_json.len());
    let mut enc = Vec::with_capacity(payload_json.len());
    for i in 0..payload_json.len() {
        enc.push(payload_json[i] ^ stream[i]);
    }
    let mut tag_input = Vec::with_capacity(nonce.len() + enc.len());
    tag_input.extend_from_slice(&nonce);
    tag_input.extend_from_slice(&enc);
    let full_tag = primitives::hmac_sha256(secret_bytes, &tag_input);
    let tag_hex: String = primitives::hex(&full_tag).chars().take(16).collect();

    let nonce_hex = primitives::hex(&nonce);
    let payload_b64 = primitives::base64url_nopad(&enc);

    // Compose compact JSON by hand so the four sealed field names drop in
    // verbatim — no leaked literals here.
    let mut out = String::with_capacity(128 + payload_b64.len());
    out.push('{');
    out.push('"');
    out.push_str(&f_schema);
    out.push_str("\":");
    out.push_str(&rev.to_string());
    out.push(',');
    out.push('"');
    out.push_str(&f_nonce);
    out.push_str("\":\"");
    out.push_str(&nonce_hex);
    out.push_str("\",\"");
    out.push_str(&f_payload);
    out.push_str("\":\"");
    out.push_str(&payload_b64);
    out.push_str("\",\"");
    out.push_str(&f_tag);
    out.push_str("\":\"");
    out.push_str(&tag_hex);
    out.push_str("\"}");
    out
}
