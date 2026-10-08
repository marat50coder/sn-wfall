import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

// ============================================================
//  DriftBridge — Dart ⇄ libdrift_signal.so (gray-flow vault)
// ============================================================
//  All sealed strings, UA fragments, JS enhancers, verdict
//  endpoint, AppsFlyer dev key and GCD base live inside the
//  Rust side. Dart receives already-decoded UTF-8 bytes from
//  a single FFI call; nothing of the plaintext survives in
//  the Dart heap longer than one function body.
//
//  Load order:
//    1. ClientBeacon.warmup() calls DriftBridge.boot()
//    2. boot() opens libdrift_signal.so once
//    3. accessor fetch(slotId) returns a String (empty on error)
//
//  All byte buffers handed out by Rust are released on this
//  side via ds_release before the Dart String is returned.
// ============================================================

// ---- Slot IDs (must match rust/drift_signal/seeds/entries.rs) --
class DriftSlot {
  DriftSlot._();
  static const int verdictEndpoint   = 0x01000001;
  static const int afKey             = 0x01000002;
  static const int gcdBase           = 0x01000003;
  static const int firebaseProject   = 0x01000004;
  static const int chromeVersion     = 0x01000018;
  static const int webkitVersion     = 0x01000019;
  static const int jsSafeArea        = 0x01000030;
  static const int jsKeyboard        = 0x01000031;
  static const int jsAutoplay        = 0x01000032;
}

// ---- FFI signatures ------------------------------------------
typedef _NativeVersion = ffi.Uint32 Function();
typedef _DartVersion = int Function();

typedef _NativeFetch = ffi.Int32 Function(
    ffi.Uint32, ffi.Pointer<ffi.Pointer<ffi.Uint8>>, ffi.Pointer<ffi.IntPtr>);
typedef _DartFetch = int Function(
    int, ffi.Pointer<ffi.Pointer<ffi.Uint8>>, ffi.Pointer<ffi.IntPtr>);

typedef _NativeUa = ffi.Int32 Function(
    ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>,
    ffi.Pointer<ffi.Pointer<ffi.Uint8>>, ffi.Pointer<ffi.IntPtr>);
typedef _DartUa = int Function(
    ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>,
    ffi.Pointer<ffi.Pointer<ffi.Uint8>>, ffi.Pointer<ffi.IntPtr>);

typedef _NativeGcd = ffi.Int32 Function(
    ffi.Pointer<Utf8>, ffi.Pointer<Utf8>,
    ffi.Pointer<ffi.Pointer<ffi.Uint8>>, ffi.Pointer<ffi.IntPtr>);
typedef _DartGcd = int Function(
    ffi.Pointer<Utf8>, ffi.Pointer<Utf8>,
    ffi.Pointer<ffi.Pointer<ffi.Uint8>>, ffi.Pointer<ffi.IntPtr>);

typedef _NativeFree = ffi.Int32 Function(ffi.Pointer<ffi.Uint8>, ffi.IntPtr);
typedef _DartFree = int Function(ffi.Pointer<ffi.Uint8>, int);

class DriftBridge {
  DriftBridge._();

  static ffi.DynamicLibrary? _lib;
  static _DartFetch? _fetch;
  static _DartUa? _ua;
  static _DartGcd? _gcd;
  static _DartFree? _free;
  static _DartVersion? _version;
  static bool _booted = false;

  /// True iff libdrift_signal.so was loaded successfully.
  static bool get ready => _booted;

  /// Open the .so once. Safe to call multiple times.
  static void boot() {
    if (_booted) return;
    try {
      if (Platform.isAndroid) {
        _lib = ffi.DynamicLibrary.open('libdrift_signal.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        _lib = ffi.DynamicLibrary.process();
      } else {
        return;
      }
      _version = _lib!
          .lookupFunction<_NativeVersion, _DartVersion>('ds_schema');
      _fetch =
          _lib!.lookupFunction<_NativeFetch, _DartFetch>('ds_pull');
      _ua = _lib!.lookupFunction<_NativeUa, _DartUa>('ds_stencil');
      _gcd = _lib!.lookupFunction<_NativeGcd, _DartGcd>('ds_track_dial');
      _free = _lib!.lookupFunction<_NativeFree, _DartFree>('ds_release');
      // Sanity check: ignore the version, just prove the symbol works.
      _version!();
      _booted = true;
    } catch (_) {
      _booted = false;
      _lib = null;
    }
  }

  /// Decode one sealed slot into a UTF-8 string.
  /// Returns "" on any failure (missing .so, unknown slot, etc).
  static String fetch(int slotId) {
    if (!_booted || _fetch == null || _free == null) return '';
    final ffi.Pointer<ffi.Pointer<ffi.Uint8>> ptrPtr =
        calloc<ffi.Pointer<ffi.Uint8>>();
    final ffi.Pointer<ffi.IntPtr> lenPtr = calloc<ffi.IntPtr>();
    try {
      final int rc = _fetch!(slotId, ptrPtr, lenPtr);
      if (rc != 0) return '';
      return _consume(ptrPtr.value, lenPtr.value);
    } finally {
      calloc.free(ptrPtr);
      calloc.free(lenPtr);
    }
  }

  /// Rust-side UA assembly. All fragments live inside the .so;
  /// Dart never holds them individually.
  static String userAgent({
    required String release,
    required String brand,
    required String model,
    required String build,
  }) {
    if (!_booted || _ua == null || _free == null) return '';
    final ffi.Pointer<Utf8> rPtr = release.toNativeUtf8();
    final ffi.Pointer<Utf8> bPtr = brand.toNativeUtf8();
    final ffi.Pointer<Utf8> mPtr = model.toNativeUtf8();
    final ffi.Pointer<Utf8> dPtr = build.toNativeUtf8();
    final ffi.Pointer<ffi.Pointer<ffi.Uint8>> ptrPtr =
        calloc<ffi.Pointer<ffi.Uint8>>();
    final ffi.Pointer<ffi.IntPtr> lenPtr = calloc<ffi.IntPtr>();
    try {
      final int rc = _ua!(rPtr, bPtr, mPtr, dPtr, ptrPtr, lenPtr);
      if (rc != 0) return '';
      return _consume(ptrPtr.value, lenPtr.value);
    } finally {
      calloc.free(rPtr);
      calloc.free(bPtr);
      calloc.free(mPtr);
      calloc.free(dPtr);
      calloc.free(ptrPtr);
      calloc.free(lenPtr);
    }
  }

  /// Rust-side GCD URL assembly: base + app_id + ?devkey=…&device_id=…
  /// The dev key never crosses the FFI boundary as a Dart string.
  static String gcdCallUrl({
    required String appId,
    required String deviceId,
  }) {
    if (!_booted || _gcd == null || _free == null) return '';
    final ffi.Pointer<Utf8> aPtr = appId.toNativeUtf8();
    final ffi.Pointer<Utf8> dPtr = deviceId.toNativeUtf8();
    final ffi.Pointer<ffi.Pointer<ffi.Uint8>> ptrPtr =
        calloc<ffi.Pointer<ffi.Uint8>>();
    final ffi.Pointer<ffi.IntPtr> lenPtr = calloc<ffi.IntPtr>();
    try {
      final int rc = _gcd!(aPtr, dPtr, ptrPtr, lenPtr);
      if (rc != 0) return '';
      return _consume(ptrPtr.value, lenPtr.value);
    } finally {
      calloc.free(aPtr);
      calloc.free(dPtr);
      calloc.free(ptrPtr);
      calloc.free(lenPtr);
    }
  }

  // ---- internal ------------------------------------------------
  static String _consume(ffi.Pointer<ffi.Uint8> ptr, int len) {
    if (ptr == ffi.nullptr || len <= 0) return '';
    try {
      final List<int> bytes =
          ptr.asTypedList(len).toList(growable: false);
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      _free!(ptr, len);
    }
  }
}
