#!/usr/bin/env bash
# ============================================================
# build_rust.sh — compile drift_signal for the three Android ABIs
# ============================================================
#
# Prerequisites (one-time per workstation):
#   rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
#   export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/27.0.12077973
#
# The script writes stripped libdrift_signal.so into:
#   android/app/src/main/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/
#
# These .so files are COMMITTED to git so that any clone can
# build the APK without a Rust toolchain. Regenerate them
# whenever rust/drift_signal/** changes.
# ============================================================

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CRATE="$ROOT/rust/drift_signal"
JNI="$ROOT/android/app/src/main/jniLibs"
LIB_NAME="libdrift_signal.so"

: "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME to your NDK install}"
API=26
HOST="darwin-x86_64"
if [[ "$(uname -s)" == "Linux" ]]; then HOST="linux-x86_64"; fi
BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST/bin"

build_one() {
  local triple="$1"
  local out_dir="$2"
  local linker="$3"
  local ar="$BIN/llvm-ar"

  echo "▶ $triple → $out_dir"
  mkdir -p "$out_dir"

  export CC_${triple//-/_}="$BIN/$linker"
  export AR_${triple//-/_}="$ar"
  export CARGO_TARGET_$(echo "$triple" | tr '[:lower:]-' '[:upper:]_')_LINKER="$BIN/$linker"
  export CARGO_TARGET_$(echo "$triple" | tr '[:lower:]-' '[:upper:]_')_AR="$ar"

  (cd "$CRATE" && cargo build --release --target "$triple" --lib)

  cp "$CRATE/target/$triple/release/$LIB_NAME" "$out_dir/$LIB_NAME"
  "$BIN/llvm-strip" --strip-unneeded "$out_dir/$LIB_NAME" || true
  ls -l "$out_dir/$LIB_NAME"
}

# Regenerate the ciphertext table before every build.
echo "▶ packing sealed table"
(cd "$CRATE" && cargo run --release --bin pack_seals >/dev/null)

build_one aarch64-linux-android    "$JNI/arm64-v8a"    "aarch64-linux-android${API}-clang"
build_one armv7-linux-androideabi  "$JNI/armeabi-v7a"  "armv7a-linux-androideabi${API}-clang"
build_one x86_64-linux-android     "$JNI/x86_64"       "x86_64-linux-android${API}-clang"

echo "✓ drift_signal built for 3 ABIs"
