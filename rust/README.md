# gate_core

Rust side of the gray-part machinery. Compiled to `libgate_core.so` for
`arm64-v8a`, `armeabi-v7a` and `x86_64`, placed into
`android/app/src/main/jniLibs/<abi>/libgate_core.so` and shipped inside the
APK.

The crate hosts every URL, user-agent fragment, JS injection and secret
key used by the gray flow. Nothing of this leaks into the Dart source:
Flutter only calls through FFI (see `lib/gate/gate_core.dart`).

## Layout

```
rust/gate_core/
├── Cargo.toml
├── build.rs                 ← reads sealed/seed.toml, XOR-encrypts every
│                             entry and emits src/sealed_data.rs
├── sealed/
│   ├── seed.toml            ← REAL VALUES, GITIGNORED
│   └── seed.example.toml    ← template for teammates
└── src/
    ├── lib.rs               ← FFI exports (gate_unseal, gate_fetch_config, …)
    ├── seal.rs              ← per-slot XOR keystream (mirror of build.rs)
    ├── sealed_data.rs       ← AUTO-GENERATED, GITIGNORED
    ├── theme.rs             ← user-agent builder
    └── config.rs            ← ureq-rustls POST to the sealed endpoint
```

## Build

```bash
# One-time setup
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo install cargo-ndk
export ANDROID_NDK_HOME=/path/to/android-ndk       # NDK r25 or newer

# Each release
./tool/build_rust.sh                               # macOS / Linux
./tool/build_rust.ps1                              # Windows (PowerShell)
```

The script places `libgate_core.so` directly into
`android/app/src/main/jniLibs/<abi>/`. **These .so files are intentionally
committed** so `flutter build apk` can never ship without them.

## Grep audit

```bash
./tool/grep_check.sh
```

Must print `✓ clean` before every release. The script fails the build if
any URL, UA fragment, bundle id, dev key or raw `print()` call leaks into
`lib/`.
