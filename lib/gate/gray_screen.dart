// ignore_for_file: public_member_api_docs
//
// WebView host for the gray experience.
//
// Expects everything (target URL, UA, JS payloads) to be supplied by the
// caller via a `GateResult`. This widget contains no URL literals, no UA
// literals, no injection literals and does not log anything in release.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'gate_service.dart';

class GrayScreen extends StatefulWidget {
  const GrayScreen({super.key, required this.result});

  final GateResult result;

  @override
  State<GrayScreen> createState() => _GrayScreenState();
}

class _GrayScreenState extends State<GrayScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final params = PlatformWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(widget.result.userAgent.isEmpty
          ? null
          : widget.result.userAgent)
      ..addJavaScriptChannel('SFOBridge', onMessageReceived: (_) {})
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          final r = widget.result;
          for (final script in [
            r.jsBootstrap,
            r.jsTelemetry,
            r.jsFrameCleanup,
          ]) {
            if (script.isEmpty) continue;
            try {
              await _controller.runJavaScript(script);
            } catch (_) {
              // Any injection failure is non-fatal; keep the page alive.
            }
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.result.target));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: WebViewWidget(controller: _controller)),
      ),
    );
  }
}
