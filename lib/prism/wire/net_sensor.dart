import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/client_dossier.dart';

// ============================================================
//  NetSensor — connectivity + DNS reachability probe
// ============================================================
//  `connectivity_plus` alone misreports under VPN tunnels and
//  captive portals. We layer a lightweight DNS lookup on top so
//  the boot pipeline only commits to online routing when at least
//  one well-known host actually resolves within the configured
//  budget. The probe rotates between two hosts so a transient
//  outage on either does not force a false offline verdict.
//
//  The probe hosts have no relationship with the partner / config
//  endpoint; probing those would log traffic before the verdict
//  POST and create a cheap sniff-based correlation.
// ============================================================

// Rotate per project — Snowfall uses `wikipedia.org` and
// `apple.com`. The template defaults were `cloudflare.com` and
// `apple.com`, so Snowfall differs by one host.
const List<String> _landmarks = <String>[
  'wikipedia.org',
  'apple.com',
];

const Set<ConnectivityResult> _liveLines = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

class NetSensor {
  NetSensor({Connectivity? connectivity})
      : _driver = connectivity ?? Connectivity();

  final Connectivity _driver;
  int _rotor = 0;

  Future<bool> hasAdapter() async {
    try {
      final List<ConnectivityResult> states =
          await _driver.checkConnectivity();
      return states.any(_liveLines.contains);
    } catch (_) {
      return false;
    }
  }

  Future<bool> canDialOut() async {
    if (!await hasAdapter()) return false;
    final Duration budget =
        Duration(seconds: ClientDossier.probeTimeoutSec);
    for (int i = 0; i < _landmarks.length; i++) {
      final String host = _landmarks[(_rotor + i) % _landmarks.length];
      try {
        final List<InternetAddress> answer =
            await InternetAddress.lookup(host).timeout(budget);
        if (answer.any((InternetAddress a) => a.rawAddress.isNotEmpty)) {
          _rotor = (_rotor + 1) % _landmarks.length;
          return true;
        }
      } catch (_) {
        // Try the next host before declaring offline.
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get updates =>
      _driver.onConnectivityChanged;
}
