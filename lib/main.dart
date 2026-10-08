import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'prism/prism_director.dart';
import 'prism/wire/aurora_vault.dart';
import 'prism/wire/client_beacon.dart';
import 'prism/wire/net_sensor.dart';
import 'prism/wire/ruling_endpoint.dart';
import 'prism/wire/signal_relay.dart';
import 'prism/wire/tracker_bureau.dart';
import 'shell/snowfall_app.dart';

// ============================================================
//  main.dart — Snowfall Odyssey bootstrap
// ============================================================
//  Order matters:
//    1. Flutter binding
//    2. Firebase + AppCheck (wrapped — the app must still boot
//       into the game branch if Firebase is misconfigured)
//    3. System UI (status/nav bar, orientations)
//    4. ClientBeacon.warmup — builds the forged UA before any
//       WebView or HTTP client is constructed
//    5. AuroraVault.warmup — loads SharedPreferences
//    6. Compose wire objects + director, mount SnowfallApp
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await ClientBeacon.warmup();

  final AuroraVault vault = AuroraVault();
  await vault.warmup();

  final NetSensor sensor = NetSensor();
  final TrackerBureau bureau = TrackerBureau();
  final RulingEndpoint endpoint = RulingEndpoint(vault);
  final SignalRelay relay = SignalRelay(vault);

  final PrismDirector director = PrismDirector(
    vault: vault,
    sensor: sensor,
    bureau: bureau,
    endpoint: endpoint,
    relay: relay,
  );

  runApp(SnowfallApp(
    director: director,
    vault: vault,
    relay: relay,
  ));
}
