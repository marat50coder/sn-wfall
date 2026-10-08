import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';
import '../snowfield/circuit/client_beacon.dart';

/// Lightweight in-app browser for the Privacy and Support
/// buttons on the game menu. Loads the URL inside a WebView with
/// the same forged UA the gray surface uses, so the two surfaces
/// never answer with different User-Agent strings.
class WebScreen extends StatefulWidget {
  const WebScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _web;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kNightBlue)
      ..setUserAgent(ClientBeacon.userAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _error = null;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          if (mounted) {
            setState(() {
              _loading = false;
              _error =
                  'This page could not be opened. Check your connection and try again.';
            });
          }
        },
      ));
    if (widget.url.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _web.loadRequest(Uri.parse(widget.url.trim()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNightBlue,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: kDeepBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: widget.url.trim().isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This page will be available soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              )
            : Stack(
                children: <Widget>[
                  WebViewWidget(controller: _web),
                  if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() => _error = null);
                                _web.loadRequest(Uri.parse(widget.url.trim()));
                              },
                              child: const Text('TRY AGAIN'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_loading) const LinearProgressIndicator(),
                ],
              ),
      ),
    );
  }
}
