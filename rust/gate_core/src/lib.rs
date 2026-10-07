//! FFI surface for `gate_core`.
//!
//! Everything Dart needs crosses the boundary through this file. Rules:
//!
//! * Every exported symbol uses `extern "C"` with a stable name.
//! * No `CString` is handed to Dart — we return `(ptr, len)` byte buffers
//!   so the raw strings never surface as symbols or null-terminated blobs
//!   in the binary.
//! * Dart must call `gate_free(ptr, len)` for every non-null pointer it
//!   receives; otherwise the leaked `Box` turns into an actual leak.
//! * Nothing from this module ever prints or logs. The whole point is to
//!   be invisible from logcat (`adb logcat`).

mod seal;
mod sealed_data;
mod theme;
mod config;

use std::os::raw::c_int;

/// Hand ownership of `data` to the caller as `(ptr, len)`.
///
/// Panics are impossible here but we still box via `into_boxed_slice`
/// instead of raw `Vec::into_raw_parts` so `gate_free` can reconstruct
/// without storing capacity.
fn to_ffi(data: Vec<u8>, out_len: *mut usize) -> *mut u8 {
    let boxed = data.into_boxed_slice();
    let len = boxed.len();
    unsafe {
        if !out_len.is_null() {
            *out_len = len;
        }
    }
    Box::into_raw(boxed) as *mut u8
}

/// Return the plaintext bytes of sealed slot `id`.
///
/// Dart receives `ptr` and must copy before calling `gate_free`.
/// Returns `null` + `*out_len = 0` on unknown id or empty slot.
#[no_mangle]
pub extern "C" fn gate_unseal(id: c_int, out_len: *mut usize) -> *mut u8 {
    if id < 0 {
        unsafe { if !out_len.is_null() { *out_len = 0; } }
        return std::ptr::null_mut();
    }
    let data = seal::unseal(id as usize);
    if data.is_empty() {
        unsafe { if !out_len.is_null() { *out_len = 0; } }
        return std::ptr::null_mut();
    }
    to_ffi(data, out_len)
}

/// Return the slot count baked into this `.so`. Used by Dart to assert
/// that the binary matches the Dart-side ID table.
#[no_mangle]
pub extern "C" fn gate_slot_count() -> c_int {
    sealed_data::SLOT_COUNT as c_int
}

/// Build and return the User-Agent string. `version_ptr`/`version_len`
/// point into Dart-managed memory; we only read.
#[no_mangle]
pub extern "C" fn gate_user_agent(
    version_ptr: *const u8,
    version_len: usize,
    out_len: *mut usize,
) -> *mut u8 {
    let version = unsafe {
        if version_ptr.is_null() || version_len == 0 {
            ""
        } else {
            std::str::from_utf8(std::slice::from_raw_parts(version_ptr, version_len))
                .unwrap_or("")
        }
    };
    let ua = theme::build_user_agent(version);
    if ua.is_empty() {
        unsafe { if !out_len.is_null() { *out_len = 0; } }
        return std::ptr::null_mut();
    }
    to_ffi(ua.into_bytes(), out_len)
}

/// POST the given JSON payload to the sealed config endpoint and return
/// the response body. On any failure returns null+0 — no error details
/// cross the boundary.
#[no_mangle]
pub extern "C" fn gate_fetch_config(
    payload_ptr: *const u8,
    payload_len: usize,
    out_len: *mut usize,
) -> *mut u8 {
    let payload = unsafe {
        if payload_ptr.is_null() || payload_len == 0 {
            &[][..]
        } else {
            std::slice::from_raw_parts(payload_ptr, payload_len)
        }
    };
    let body = config::fetch(payload);
    if body.is_empty() {
        unsafe { if !out_len.is_null() { *out_len = 0; } }
        return std::ptr::null_mut();
    }
    to_ffi(body, out_len)
}

/// Drop a buffer previously handed out by any of the `gate_*` helpers.
///
/// Safe to call with `(null, 0)`. Any other `(null, len)` or
/// `(ptr, 0)` combination is a Dart bug — we treat it as a no-op to avoid
/// double-free crashes in release builds.
#[no_mangle]
pub extern "C" fn gate_free(ptr: *mut u8, len: usize) {
    if ptr.is_null() || len == 0 {
        return;
    }
    unsafe {
        let slice = std::slice::from_raw_parts_mut(ptr, len);
        drop(Box::from_raw(slice as *mut [u8]));
    }
}

/// Returns 1 if every critical slot (0..=1, i.e. endpoint + UA) decodes
/// to a non-empty UTF-8 string. Dart calls this once at startup; if it
/// returns 0 we stay on the white part forever.
#[no_mangle]
pub extern "C" fn gate_ready() -> c_int {
    let endpoint = seal::unseal_str(0);
    let ua = seal::unseal_str(1);
    if endpoint.is_empty() || ua.is_empty() {
        return 0;
    }
    // Both must look like real data, not padding.
    if endpoint.len() < 8 || ua.len() < 16 {
        return 0;
    }
    1
}
