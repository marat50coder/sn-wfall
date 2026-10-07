#!/usr/bin/env bash
#
# Build the `gate_core` Rust crate for every Android ABI we ship and copy
# the resulting .so into Android's jniLibs so the APK/AAB include them.
#
# Prerequisites (install once):
#   rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
#   cargo install cargo-ndk
#   export ANDROID_NDK_HOME=/path/to/android-ndk      # NDK r25 or newer
#
# Usage:
#   tool/build_rust.sh            # release build (default)
#   tool/build_rust.sh --debug    # debug build (bigger .so, used only locally)
#
# NOTE: the .so files are intentionally checked into git so that nobody can
# ship an APK without them by accident. If the build is reproducible in CI
# we can revisit that.
set -euo pipefail

mode="release"
if [[ "${1:-}" == "--debug" ]]; then
  mode="debug"
fi

here="$(cd "$(dirname "$0")/.." && pwd)"
crate="$here/rust/gate_core"
jni="$here/android/app/src/main/jniLibs"

if ! command -v cargo >/dev/null; then
  echo "✖ cargo not found. Install Rust toolchain from https://rustup.rs." >&2
  exit 1
fi
if ! command -v cargo-ndk >/dev/null; then
  echo "✖ cargo-ndk not found. Install with: cargo install cargo-ndk" >&2
  exit 1
fi
if [[ -z "${ANDROID_NDK_HOME:-}${ANDROID_NDK_ROOT:-}" ]]; then
  # Fall back to the default sdkmanager location.
  if [[ -d "$HOME/Library/Android/sdk/ndk" ]]; then
    latest=$(ls "$HOME/Library/Android/sdk/ndk" | sort -V | tail -1)
    export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/$latest"
  elif [[ -d "$HOME/Android/Sdk/ndk" ]]; then
    latest=$(ls "$HOME/Android/Sdk/ndk" | sort -V | tail -1)
    export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/$latest"
  else
    echo "✖ ANDROID_NDK_HOME is not set and no NDK found in the SDK." >&2
    exit 1
  fi
fi

echo "▶ gate_core: $mode build for arm64-v8a, armeabi-v7a, x86_64"
echo "  crate   : $crate"
echo "  jniLibs : $jni"
echo "  NDK     : $ANDROID_NDK_HOME"

cd "$crate"

flags=()
if [[ "$mode" == "release" ]]; then
  flags+=("--release")
fi

mkdir -p "$jni/arm64-v8a" "$jni/armeabi-v7a" "$jni/x86_64"

cargo ndk \
  -t arm64-v8a \
  -t armeabi-v7a \
  -t x86_64 \
  -o "$jni" \
  build "${flags[@]}"

echo "✓ gate_core built. Shipped libraries:"
find "$jni" -name 'libgate_core.so' -printf '  %p (%s bytes)\n' 2>/dev/null \
  || find "$jni" -name 'libgate_core.so' -exec ls -l {} \;
