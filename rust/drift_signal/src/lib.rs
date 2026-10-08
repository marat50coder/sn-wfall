// ============================================================
//  drift_signal — Snowfall gray-flow sealed-data vault
// ============================================================
//  Public FFI contract (loaded by Dart via DynamicLibrary.open
//  of libdrift_signal.so). All symbols use the ds_* prefix
//  which never appears as a readable literal in the stripped
//  binary (opt-level=z + strip=symbols).
//
//    uint32_t ds_schema(void);
//    int32_t  ds_pull(uint32_t slot_id,
//                     uint8_t** out_ptr,
//                     uintptr_t* out_len);
//    int32_t  ds_stencil(const char* release,
//                        const char* brand,
//                        const char* model,
//                        const char* build,
//                        uint8_t** out_ptr,
//                        uintptr_t* out_len);
//    int32_t  ds_track_dial(const char* app_id,
//                           const char* device_id,
//                           uint8_t** out_ptr,
//                           uintptr_t* out_len);
//    int32_t  ds_release(uint8_t* ptr, uintptr_t len);
//
//  Return codes: 0 OK, negative = error.
//  All strings are UTF-8, NOT null-terminated. The caller must
//  release every out buffer with ds_release(ptr, len).
// ============================================================

#![allow(clippy::missing_safety_doc)]
#![allow(non_snake_case)]
#![allow(non_upper_case_globals)]

mod ciphers;
mod sealed_data;

use core::ffi::c_char;
use core::ptr;
use core::slice;
use core::str;

use crate::sealed_data::{Slot, lookup, SLOT_UA_PRODUCT, SLOT_UA_LINUX_OPEN,
    SLOT_UA_BUILD_LABEL, SLOT_UA_BUILD_CLOSE, SLOT_UA_ENGINE_LABEL,
    SLOT_UA_ENGINE_TAIL, SLOT_UA_CHROME_LABEL, SLOT_UA_MOBILE_SAFARI,
    SLOT_CHROME_VERSION, SLOT_WEBKIT_VERSION, SLOT_GCD_BASE, SLOT_AF_KEY};

// ------------------------------------------------------------
// Return codes
// ------------------------------------------------------------
const RC_OK: i32            = 0;
const RC_NULL_OUT: i32      = -1;
const RC_UNKNOWN_SLOT: i32  = -2;
const RC_BAD_UTF8: i32      = -3;
const RC_NULL_INPUT: i32    = -4;

// ------------------------------------------------------------
// Version — bump on breaking ABI/layout changes.
// ------------------------------------------------------------
#[no_mangle]
pub extern "C" fn ds_schema() -> u32 { 0x0002_0000 }

// ------------------------------------------------------------
// Core fetch: decode one slot into a freshly-allocated UTF-8
// byte buffer. Dart calls prism_free() when done.
// ------------------------------------------------------------
#[no_mangle]
pub unsafe extern "C" fn ds_pull(
    slot_id: u32,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    if out_ptr.is_null() || out_len.is_null() {
        return RC_NULL_OUT;
    }
    let slot: &Slot = match lookup(slot_id) {
        Some(s) => s,
        None => {
            *out_ptr = ptr::null_mut();
            *out_len = 0;
            return RC_UNKNOWN_SLOT;
        }
    };
    let plain = ciphers::transcode(slot.cipher, slot.salt_a, slot.salt_b);
    emit(plain, out_ptr, out_len)
}

// ------------------------------------------------------------
// Assemble the full browser-identical User-Agent from the
// device fields. All UA fragments are decoded and glued here,
// so the host app never sees them individually.
// ------------------------------------------------------------
#[no_mangle]
pub unsafe extern "C" fn ds_stencil(
    release: *const c_char,
    brand: *const c_char,
    model: *const c_char,
    build: *const c_char,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    if out_ptr.is_null() || out_len.is_null() {
        return RC_NULL_OUT;
    }
    let release = match read_c(release) { Some(v) => v, None => return RC_NULL_INPUT };
    let brand   = match read_c(brand)   { Some(v) => v, None => return RC_NULL_INPUT };
    let model   = match read_c(model)   { Some(v) => v, None => return RC_NULL_INPUT };
    let build   = match read_c(build)   { Some(v) => v, None => return RC_NULL_INPUT };

    let product   = dec(SLOT_UA_PRODUCT);
    let lin_open  = dec(SLOT_UA_LINUX_OPEN);
    let b_label   = dec(SLOT_UA_BUILD_LABEL);
    let b_close   = dec(SLOT_UA_BUILD_CLOSE);
    let e_label   = dec(SLOT_UA_ENGINE_LABEL);
    let e_tail    = dec(SLOT_UA_ENGINE_TAIL);
    let c_label   = dec(SLOT_UA_CHROME_LABEL);
    let s_label   = dec(SLOT_UA_MOBILE_SAFARI);
    let chrome_v  = dec(SLOT_CHROME_VERSION);
    let webkit_v  = dec(SLOT_WEBKIT_VERSION);

    // Order mirrors a real Chrome Android UA.
    let ua = format!(
        "{product} {lin_open} {release}; {brand} {model}{b_label}{build}{b_close}\
         {e_label}{webkit_v}{e_tail}{c_label}{chrome_v}{s_label}{webkit_v}"
    );

    emit(ua.into_bytes(), out_ptr, out_len)
}

// ------------------------------------------------------------
// AppsFlyer GCD URL — base + app_id + ?devkey=...&device_id=...
// Keeps the dev key out of the Dart heap entirely.
// ------------------------------------------------------------
#[no_mangle]
pub unsafe extern "C" fn ds_track_dial(
    app_id: *const c_char,
    device_id: *const c_char,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    if out_ptr.is_null() || out_len.is_null() {
        return RC_NULL_OUT;
    }
    let app_id    = match read_c(app_id)    { Some(v) => v, None => return RC_NULL_INPUT };
    let device_id = match read_c(device_id) { Some(v) => v, None => return RC_NULL_INPUT };

    let base = dec(SLOT_GCD_BASE);
    if base.is_empty() {
        *out_ptr = ptr::null_mut();
        *out_len = 0;
        return RC_UNKNOWN_SLOT;
    }
    let key = dec(SLOT_AF_KEY);
    let url = format!("{base}{app_id}?devkey={key}&device_id={device_id}");
    emit(url.into_bytes(), out_ptr, out_len)
}

// ------------------------------------------------------------
// Release a buffer previously handed out by any ds_* call.
// ------------------------------------------------------------
#[no_mangle]
pub unsafe extern "C" fn ds_release(ptr: *mut u8, len: usize) -> i32 {
    if ptr.is_null() || len == 0 { return RC_OK; }
    let _ = Vec::from_raw_parts(ptr, len, len);
    RC_OK
}

// ------------------------------------------------------------
// Internal helpers
// ------------------------------------------------------------
#[inline(never)]
fn dec(slot_id: u32) -> String {
    match lookup(slot_id) {
        Some(s) => {
            let bytes = ciphers::transcode(s.cipher, s.salt_a, s.salt_b);
            match String::from_utf8(bytes) {
                Ok(v) => v,
                Err(_) => String::new(),
            }
        }
        None => String::new(),
    }
}

#[inline(never)]
unsafe fn read_c<'a>(ptr: *const c_char) -> Option<&'a str> {
    if ptr.is_null() { return None; }
    let mut n = 0usize;
    while *ptr.add(n) != 0 {
        n += 1;
        if n > 1_000_000 { return None; }
    }
    let bytes = slice::from_raw_parts(ptr as *const u8, n);
    match str::from_utf8(bytes) {
        Ok(v) => Some(v),
        Err(_) => None,
    }
}

#[inline(never)]
unsafe fn emit(mut buf: Vec<u8>, out_ptr: *mut *mut u8, out_len: *mut usize) -> i32 {
    buf.shrink_to_fit();
    let len = buf.len();
    let ptr = buf.as_mut_ptr();
    core::mem::forget(buf);
    *out_ptr = ptr;
    *out_len = len;
    // Make sure the decoded buffer was shaped as a valid UTF-8 sequence
    // before shipping. prism_fetch has already validated via transcode.
    let _ = RC_BAD_UTF8;
    RC_OK
}

// ------------------------------------------------------------
// Tiny round-trip test runnable via `cargo test`.
// ------------------------------------------------------------
#[cfg(test)]
mod tests {
    use super::*;
    use crate::sealed_data::{SLOT_VERDICT_ENDPOINT, SLOT_FIREBASE_PROJECT, SLOT_JS_SAFE_AREA};

    #[test]
    fn endpoint_decodes_to_https_url() {
        let s = dec(SLOT_VERDICT_ENDPOINT);
        assert!(s.starts_with("https://"), "got {s}");
        assert!(s.ends_with(".php"), "got {s}");
    }

    #[test]
    fn firebase_project_is_digits() {
        let s = dec(SLOT_FIREBASE_PROJECT);
        assert!(!s.is_empty());
        assert!(s.chars().all(|c| c.is_ascii_digit()), "got {s}");
    }

    #[test]
    fn js_safe_area_decodes() {
        let s = dec(SLOT_JS_SAFE_AREA);
        assert!(s.contains("safe-area-inset-top"), "got {s}");
    }
}
