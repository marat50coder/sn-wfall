import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../snowfield/snowfield_director.dart';
import '../snowfield/circuit/aurora_vault.dart';
import '../snowfield/circuit/client_beacon.dart';
import '../snowfield/circuit/net_sensor.dart';
import '../snowfield/circuit/verdict_hub.dart';
import '../snowfield/circuit/push_dispatch.dart';
import '../snowfield/circuit/install_registry.dart';
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
  final InstallRegistry bureau = InstallRegistry();
  final VerdictHub endpoint = VerdictHub(vault);
  final PushDispatch relay = PushDispatch(vault);

  final SnowfieldDirector director = SnowfieldDirector(
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
