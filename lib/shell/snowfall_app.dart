import 'package:flutter/material.dart';

import '../prelude/boot_canvas.dart';
import '../prism/config/client_dossier.dart';
import '../prism/prism_director.dart';
import '../prism/wire/aurora_vault.dart';
import '../prism/wire/signal_relay.dart';
import 'snowfall_theme.dart';

/// Root widget. Owns the long-lived infrastructure (vault,
/// relay, director) and hands them to the boot canvas.
class SnowfallApp extends StatelessWidget {
  const SnowfallApp({
    super.key,
    required this.director,
    required this.vault,
    required this.relay,
  });

  final PrismDirector director;
  final AuroraVault vault;
  final SignalRelay relay;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ClientDossier.displayName,
      debugShowCheckedModeBanner: false,
      theme: SnowfallTheme.build(),
      home: BootCanvas(
        director: director,
        vault: vault,
        relay: relay,
      ),
    );
  }
}
