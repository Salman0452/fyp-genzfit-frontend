import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Avaturn avatar customiser screen.
///
/// Opens the Avaturn editor in a WebView using their JS SDK.
/// When the user clicks "Next / Export", the SDK fires an "export" event
/// containing the GLB URL which we intercept and return to the caller.
///
/// Returns: String? — the full Avaturn avatar .glb URL, or null if cancelled.
///
/// Subdomain "demo" works for free testing with no sign-up.
/// Create your own at https://developer.avaturn.me/ for production.
class RpmAvatarScreen extends StatefulWidget {
  /// Avaturn subdomain — "demo" works for free testing.
  /// Create your own project at https://developer.avaturn.me/
  final String subdomain;

  const RpmAvatarScreen({super.key, required this.subdomain});

  @override
  State<RpmAvatarScreen> createState() => _RpmAvatarScreenState();
}

class _RpmAvatarScreenState extends State<RpmAvatarScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  // Avaturn base URL — no extra query params needed for the SDK approach
  String get _avaturnUrl => 'https://${widget.subdomain}.avaturn.dev';

  // HTML page we load locally: embeds the Avaturn SDK and posts back the GLB URL
  String get _htmlPage => '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #1A1A2E; overflow: hidden; }
    #avaturn-sdk-container { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <div id="avaturn-sdk-container"></div>
  <script type="module">
    import { AvaturnSDK } from "https://cdn.jsdelivr.net/npm/@avaturn/sdk/dist/index.js";

    async function loadAvaturn() {
      const container = document.getElementById("avaturn-sdk-container");
      const url = "${_avaturnUrl}";
      const sdk = new AvaturnSDK();

      try {
        await sdk.init(container, { url });

        sdk.on("export", (data) => {
          // data.url is the GLB download URL
          const glbUrl = data.url || (data.avatarUrl) || "";
          if (glbUrl) {
            // Send to Flutter via JS channel
            AvaturnChannel.postMessage(JSON.stringify({ url: glbUrl, data: data }));
          }
        });
      } catch(e) {
        AvaturnChannel.postMessage(JSON.stringify({ error: e.toString() }));
      }
    }

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", loadAvaturn);
    } else {
      loadAvaturn();
    }
  </script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF1A1A2E))
          // Spoof a Chrome desktop user-agent so Google allows OAuth in this WebView
          ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 10; Mobile) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/120.0.0.0 Mobile Safari/537.36',
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) => setState(() => _loading = true),
              onPageFinished: (_) => setState(() => _loading = false),
              onWebResourceError: (err) {
                // Ignore sub-resource errors (fonts, analytics etc.)
                if (err.isForMainFrame == true) {
                  setState(() => _error = err.description);
                }
              },
              onNavigationRequest: (req) {
                final url = req.url;
                // Google OAuth blocks embedded WebViews — open in the real browser instead
                if (url.contains('accounts.google.com') ||
                    url.contains('oauth2.googleapis.com') ||
                    url.contains('google.com/o/oauth2')) {
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..addJavaScriptChannel(
            'AvaturnChannel',
            onMessageReceived: _onMessage,
          )
          ..loadHtmlString(_htmlPage, baseUrl: _avaturnUrl);
  }

  void _onMessage(JavaScriptMessage msg) {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        setState(() => _error = data['error'] as String?);
        return;
      }

      final glbUrl = data['url'] as String?;
      if (glbUrl != null && glbUrl.isNotEmpty && mounted) {
        Navigator.pop(context, glbUrl);
      }
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _error = null;
      _loading = true;
    });
    _controller.loadHtmlString(_htmlPage, baseUrl: _avaturnUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: const Text(
          'Create Your Avatar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body:
          _error != null
              ? _buildError()
              : Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    Container(
                      color: const Color(0xFF1A1A2E),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Loading Avatar Creator…',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load avatar creator',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
