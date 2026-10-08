import 'package:http/http.dart' as http;

import 'client_beacon.dart';

// ============================================================
//  WireCourier — HTTP client that always carries the forged UA
// ============================================================
//  All verdict POSTs, GCD rescue GETs and push-image fetches go
//  through this one agent so a request can never escape with the
//  default Dart `dart-io/x.y` user agent (a well-known Flutter
//  signature).
// ============================================================

class WireCourier extends http.BaseClient {
  WireCourier();

  final http.Client _courier = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = ClientBeacon.userAgent;
    return _courier.send(request);
  }

  @override
  void close() => _courier.close();
}

/// Shared singleton — primed after `ClientBeacon.warmup()` in main().
final WireCourier wireCourier = WireCourier();
