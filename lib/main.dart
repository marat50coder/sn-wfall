import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SnowfallApp());
}

class SnowfallApp extends StatelessWidget {
  const SnowfallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snowfall Odyssey',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoadingScreen(),
    );
  }
}
