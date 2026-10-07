// ignore_for_file: public_member_api_docs
//
// Dart-side binding for `libgate_core.so`.
//
// All sealed data (URLs, user-agent, JS injections) is fetched through
// this layer. Rules we enforce here:
//
//   * No string literal in this file ever contains a URL, a bundle id,
//     an endpoint path, a user-agent or anything else that an attacker
//     grepping the APK could use. The only literal strings are symbol
//     names (`gate_unseal`, `gate_free`, …), which match the exports in
//     `lib.rs`.
//   * Every pointer returned by Rust is copied to a Dart-owned list and
//     the native memory is immediately released via `gate_free`.
//   * On any FFI failure we return an empty value; the caller treats
//     "empty" as "stay on the white part".

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'sealed_ids.dart';

typedef _GateUnsealNative = Pointer<Uint8> Function(
    Int32 id, Pointer<Size> outLen);
typedef _GateUnsealDart = Pointer<Uint8> Function(
    int id, Pointer<Size> outLen);

typedef _GateUserAgentNative = Pointer<Uint8> Function(
    Pointer<Uint8> versionPtr, Size versionLen, Pointer<Size> outLen);
typedef _GateUserAgentDart = Pointer<Uint8> Function(
    Pointer<Uint8> versionPtr, int versionLen, Pointer<Size> outLen);

typedef _GateFetchConfigNative = Pointer<Uint8> Function(
    Pointer<Uint8> payloadPtr, Size payloadLen, Pointer<Size> outLen);
typedef _GateFetchConfigDart = Pointer<Uint8> Function(
    Pointer<Uint8> payloadPtr, int payloadLen, Pointer<Size> outLen);

typedef _GateFreeNative = Void Function(Pointer<Uint8> ptr, Size len);
typedef _GateFreeDart = void Function(Pointer<Uint8> ptr, int len);

typedef _GateSlotCountNative = Int32 Function();
typedef _GateSlotCountDart = int Function();

typedef _GateReadyNative = Int32 Function();
typedef _GateReadyDart = int Function();

class GateCore {
  GateCore._(DynamicLibrary lib)
      : _unseal = lib
            .lookupFunction<_GateUnsealNative, _GateUnsealDart>('gate_unseal'),
        _ua = lib.lookupFunction<_GateUserAgentNative, _GateUserAgentDart>(
            'gate_user_agent'),
        _fetchConfig =
            lib.lookupFunction<_GateFetchConfigNative, _GateFetchConfigDart>(
                'gate_fetch_config'),
        _free =
            lib.lookupFunction<_GateFreeNative, _GateFreeDart>('gate_free'),
        _slotCount =
            lib.lookupFunction<_GateSlotCountNative, _GateSlotCountDart>(
                'gate_slot_count'),
        _ready =
            lib.lookupFunction<_GateReadyNative, _GateReadyDart>('gate_ready');

  static GateCore? _instance;
  static bool _available = false;

  final _GateUnsealDart _unseal;
  final _GateUserAgentDart _ua;
  final _GateFetchConfigDart _fetchConfig;
  final _GateFreeDart _free;
  final _GateSlotCountDart _slotCount;
  final _GateReadyDart _ready;

  /// Open the native library. Safe to call repeatedly; subsequent calls
  /// return the cached instance. Returns `null` when the .so is missing
  /// or ABI-incompatible — the caller stays on the white part.
  static GateCore? open() {
    if (_instance != null) return _instance;
    try {
      if (!Platform.isAndroid) return null;
      final lib = DynamicLibrary.open('libgate_core.so');
      final inst = GateCore._(lib);
      // Pack sanity: the number of slots the .so was built with must match
      // the Dart ID table. Any mismatch means a stale .so is shipped and
      // we refuse to run the gray part until it is rebuilt.
      if (inst._slotCount() != SealedId.all.length) return null;
      if (inst._ready() != 1) return null;
      _instance = inst;
      _available = true;
      return inst;
    } catch (_) {
      return null;
    }
  }

  /// Whether `open()` succeeded at least once this process.
  static bool get available => _available;

  /// Fetch sealed slot `id` as raw bytes. Returns an empty list on any
  /// failure (unknown slot, empty seal, stale .so).
  Uint8List unseal(SealedId id) {
    final outLen = calloc<Size>();
    try {
      final ptr = _unseal(id.index, outLen);
      final len = outLen.value;
      if (ptr == nullptr || len == 0) {
        return Uint8List(0);
      }
      final copy = Uint8List.fromList(ptr.asTypedList(len));
      _free(ptr, len);
      return copy;
    } catch (_) {
      return Uint8List(0);
    } finally {
      calloc.free(outLen);
    }
  }

  /// Fetch sealed slot `id` as a UTF-8 string. Returns `''` on failure.
  String unsealString(SealedId id) {
    final bytes = unseal(id);
    if (bytes.isEmpty) return '';
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return '';
    }
  }

  /// Build the final User-Agent using Rust-side template expansion.
  String userAgent(String version) {
    final verBytes = utf8.encode(version);
    final verPtr = calloc<Uint8>(verBytes.length);
    final outLen = calloc<Size>();
    try {
      for (var i = 0; i < verBytes.length; i++) {
        verPtr[i] = verBytes[i];
      }
      final ptr = _ua(verPtr, verBytes.length, outLen);
      final len = outLen.value;
      if (ptr == nullptr || len == 0) return '';
      final copy = Uint8List.fromList(ptr.asTypedList(len));
      _free(ptr, len);
      return utf8.decode(copy);
    } catch (_) {
      return '';
    } finally {
      calloc.free(verPtr);
      calloc.free(outLen);
    }
  }

  /// POST [payload] to the sealed config endpoint via the Rust relay and
  /// return the decoded JSON. Returns `null` on any transport error so
  /// the caller can fall back to the white part.
  Map<String, dynamic>? fetchConfig(Map<String, dynamic> payload) {
    final body = utf8.encode(jsonEncode(payload));
    final buf = calloc<Uint8>(body.length);
    final outLen = calloc<Size>();
    try {
      for (var i = 0; i < body.length; i++) {
        buf[i] = body[i];
      }
      final ptr = _fetchConfig(buf, body.length, outLen);
      final len = outLen.value;
      if (ptr == nullptr || len == 0) return null;
      final copy = Uint8List.fromList(ptr.asTypedList(len));
      _free(ptr, len);
      final decoded = jsonDecode(utf8.decode(copy));
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    } finally {
      calloc.free(buf);
      calloc.free(outLen);
    }
  }
}
