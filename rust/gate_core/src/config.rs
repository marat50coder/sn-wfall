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

use std::io::Read;
use std::time::Duration;

use crate::seal;
use crate::theme;
use crate::veil;

/// Pack `payload_json` into the sealed envelope and POST it to the
/// sealed edge-relay URL. Returns the upstream response body on 2xx;
/// empty vector on any error.
pub fn fetch(payload_json: &[u8]) -> Vec<u8> {
    let url = seal::unseal_str(0);
    if url.is_empty() {
        return Vec::new();
    }
    let envelope = veil::pack(payload_json);
    if envelope.is_empty() {
        return Vec::new();
    }

    let ua = theme::build_user_agent("1");

    let agent = ureq::AgentBuilder::new()
        .timeout(Duration::from_secs(12))
        .user_agent(&ua)
        .build();

    let resp = match agent
        .post(&url)
        .set("Content-Type", "application/json")
        .set("Accept", "application/json")
        .send_string(&envelope)
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
