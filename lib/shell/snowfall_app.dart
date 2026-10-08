import 'package:flutter/material.dart';

import '../prelude/boot_canvas.dart';
import '../snowfield/dossier/client_dossier.dart';
import '../snowfield/snowfield_director.dart';
import '../snowfield/circuit/aurora_vault.dart';
import '../snowfield/circuit/push_dispatch.dart';
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

  final SnowfieldDirector director;
  final AuroraVault vault;
  final PushDispatch relay;

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
