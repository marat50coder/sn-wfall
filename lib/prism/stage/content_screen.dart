import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config/client_dossier.dart';
import '../wire/aurora_vault.dart';
import '../wire/client_beacon.dart';
import '../wire/net_sensor.dart';
import '../wire/page_harness.dart';
import '../wire/signal_relay.dart';
import 'offline_screen.dart';

// ============================================================
//  ContentScreen — WebView host for the gray surface
// ============================================================
//  Carries the same forged UA as the HTTP client. Both
//  orientations, immersive system UI, external-scheme hand-off,
//  bounded redirect-loop retries, debounced connectivity guard,
//  warm push URL delivery, native file chooser over a dedicated
//  MethodChannel.
//
//  NO funnel classification happens here. Any funnel the business
//  needs lives on the server; the client is a dumb shell.
// ============================================================

class ContentScreen extends StatefulWidget {
  const ContentScreen({
    super.key,
    required this.url,
    required this.vault,
    required this.relay,
  });

  final String url;
  final AuroraVault vault;
  final SignalRelay relay;

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _escaped = false;
  String? _lastMainFrame;
  int _retryCount = 0;
  Timer? _dropDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// Snowfall-specific MethodChannel. Keep in sync with
  /// MainActivity.kt → `channelName`.
  static const MethodChannel _fileBridge =
      MethodChannel('com.snowfallodyssey.odysseygame.filebridge');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _spawnController();

    widget.relay.onTargetArrived = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    _connSub = NetSensor().updates.listen((List<ConnectivityResult> r) {
      final bool allNone = r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _dropDebounce?.cancel();
        return;
      }
      _dropDebounce?.cancel();
      _dropDebounce = Timer(
        Duration(milliseconds: ClientDossier.dropDebounceMs),
        _escapeOffline,
      );
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  void _spawnController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(ClientBeacon.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _retryCount = 0;
          PageHarness.installAll(_web);
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _wireAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final String desc = err.description.toLowerCase();
    final bool isLoop = desc.contains('too_many_redirects') ||
        desc.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;

    if (isLoop &&
        _lastMainFrame != null &&
        _retryCount < ClientDossier.redirectLoopRetries) {
      _retryCount++;
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }

    // Cover the WebView's native error page immediately.
    if (mounted) setState(() => _spinner = true);

    final bool isConnectivity = desc.contains('name_not_resolved') ||
        desc.contains('address_unreachable') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (isConnectivity) {
      _escapeOffline();
    } else {
      _escapeOfflineIfDown();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inApp = <String>{
      'http',
      'https',
      'about',
      'data',
      'blob',
    };
    if (inApp.contains(uri.scheme)) {
      if (req.isMainFrame) _lastMainFrame = req.url;
      return NavigationDecision.navigate;
    }
    _handoffExternal(uri);
    return NavigationDecision.prevent;
  }

  void _wireAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController controller =
        _web.platform as AndroidWebViewController;

    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    controller.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _fileBridge
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _handoffExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _escapeOfflineIfDown() async {
    if (_escaped) return;
    final bool online = await NetSensor().canDialOut();
    if (online) return;
    _escapeOffline();
  }

  void _escapeOffline() {
    if (_escaped || !mounted) return;
    _escaped = true;
    final String current = _lastMainFrame ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineScreen(
          onRetryBuild: (_) => ContentScreen(
            url: current,
            vault: widget.vault,
            relay: widget.relay,
          ),
        ),
      ),
    );
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropDebounce?.cancel();
    _connSub?.cancel();
    widget.relay.onTargetArrived = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: MediaQuery.viewPaddingOf(context),
              child: WebViewWidget(controller: _web),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF9CD4FF)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
