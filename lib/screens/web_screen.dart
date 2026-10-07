import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';

class WebScreen extends StatefulWidget {
  const WebScreen({
    super.key,
    required this.title,
    required this.url,
    this.userAgent = '',
  });

  final String title;
  final String url;
  final String userAgent;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kNightBlue)
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
        onWebResourceError: (err) {
          if (err.isForMainFrame != true) return;
          if (mounted) {
            setState(() {
              _loading = false;
              _error = 'This page could not be opened. Check your connection and try again.';
            });
          }
        },
      ));
    if (widget.userAgent.trim().isNotEmpty) {
      _controller.setUserAgent(widget.userAgent);
    }
    if (widget.url.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.loadRequest(Uri.parse(widget.url.trim()));
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
                children: [
                  WebViewWidget(controller: _controller),
                  if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() => _error = null);
                                _controller.loadRequest(Uri.parse(widget.url.trim()));
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
