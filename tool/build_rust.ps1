# PowerShell twin of build_rust.sh for Windows contributors.
#
# Usage:
#   .\tool\build_rust.ps1              # release (default)
#   .\tool\build_rust.ps1 -Mode debug  # debug
param(
  [ValidateSet('release','debug')]
  [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'

$here = Resolve-Path (Join-Path $PSScriptRoot '..')
$crate = Join-Path $here 'rust\gate_core'
$jni = Join-Path $here 'android\app\src\main\jniLibs'

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
  throw 'cargo not found. Install Rust toolchain from https://rustup.rs.'
}
if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
  throw 'cargo-ndk not found. Install with: cargo install cargo-ndk'
}
if (-not $env:ANDROID_NDK_HOME -and -not $env:ANDROID_NDK_ROOT) {
  $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk\ndk'
  if (Test-Path $sdk) {
    $latest = Get-ChildItem $sdk | Sort-Object Name -Descending | Select-Object -First 1
    $env:ANDROID_NDK_HOME = $latest.FullName
  } else {
    throw 'ANDROID_NDK_HOME is not set and no NDK was found in the Android SDK.'
  }
}

Write-Host "> gate_core: $Mode build for arm64-v8a, armeabi-v7a, x86_64"
Write-Host "  crate   : $crate"
Write-Host "  jniLibs : $jni"
Write-Host "  NDK     : $env:ANDROID_NDK_HOME"

Set-Location $crate

$flags = @()
if ($Mode -eq 'release') { $flags += '--release' }

New-Item -ItemType Directory -Force -Path (Join-Path $jni 'arm64-v8a') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $jni 'armeabi-v7a') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $jni 'x86_64') | Out-Null

cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o $jni build @flags
if ($LASTEXITCODE -ne 0) { throw "cargo ndk failed with exit code $LASTEXITCODE" }

Write-Host "+ gate_core built. Shipped libraries:"
Get-ChildItem -Path $jni -Recurse -Filter 'libgate_core.so' | ForEach-Object {
  Write-Host "  $($_.FullName) ($($_.Length) bytes)"
}
