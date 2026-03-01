import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/ready_player_me_service.dart';
import '../../utils/constants.dart';

/// Full-screen WebView that opens the Ready Player Me fullbody avatar creator.
///
/// Ready Player Me sends a JavaScript `postMessage` when the user finishes
/// creating their avatar. We intercept that message, extract the avatar URL
/// (e.g. https://models.readyplayer.me/abc123.glb), save it to Firestore,
/// and pop back to the caller with the URL as the route result.
///
/// Usage:
/// ```dart
/// final avatarUrl = await Navigator.push<String>(
///   context,
///   MaterialPageRoute(builder: (_) => const AvatarCreatorScreen()),
/// );
/// ```
class AvatarCreatorScreen extends StatefulWidget {
  const AvatarCreatorScreen({super.key});

  @override
  State<AvatarCreatorScreen> createState() => _AvatarCreatorScreenState();
}

class _AvatarCreatorScreenState extends State<AvatarCreatorScreen> {
  final ReadyPlayerMeService _rpmService = ReadyPlayerMeService();

  late final WebViewController _controller;
  bool _isLoading = true;
  String _statusMessage = 'Loading avatar creator…';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) {
            setState(() => _isLoading = false);
            // Inject listener for RPM postMessage events.
            _controller.runJavaScript(_rpmMessageListenerJs);
          },
          onWebResourceError: (err) {
            setState(() =>
                _statusMessage = 'Error loading creator: ${err.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterRPM',
        onMessageReceived: _onRpmMessage,
      )
      ..loadRequest(Uri.parse(_rpmService.creatorIframeUrl));
  }

  // ── RPM postMessage handler ────────────────────────────────────────────────

  void _onRpmMessage(JavaScriptMessage message) async {
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      final eventName = payload['eventName'] as String?;

      if (eventName == 'v1.avatar.exported') {
        final avatarUrl = (payload['data'] as Map?)
                ?.entries
                .firstWhere(
                  (e) => e.key == 'url',
                  orElse: () => const MapEntry('url', null),
                )
                .value as String? ??
            payload['data'] as String?;

        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          await _saveAvatar(avatarUrl);
        }
      }
    } catch (_) {
      // Non-JSON messages (e.g. "v1.frame.ready") — ignore.
    }
  }

  Future<void> _saveAvatar(String avatarUrl) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _statusMessage = 'Saving your avatar…';
    });

    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId != null) {
      await _rpmService.saveBaseAvatarUrl(userId, avatarUrl);
    }

    if (mounted) {
      Navigator.pop(context, avatarUrl);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Your Avatar',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLoading || _saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading || _saving)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          // Help banner at the bottom.
          if (!_isLoading && !_saving)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: Colors.black.withOpacity(0.75),
                child: const Text(
                  'Customise your face, hair, skin & clothes — then tap "Next" to save.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── JavaScript injected after page load ───────────────────────────────────────

/// Listens for Ready Player Me postMessage events and forwards them to Flutter
/// via the FlutterRPM channel.
const String _rpmMessageListenerJs = '''
(function() {
  if (window._rpmListenerAttached) return;
  window._rpmListenerAttached = true;

  window.addEventListener('message', function(event) {
    try {
      var data = event.data;
      // RPM sends either an object or a JSON string.
      if (typeof data === 'string') {
        try { data = JSON.parse(data); } catch(e) { return; }
      }
      if (data && data.source === 'readyplayerme') {
        FlutterRPM.postMessage(JSON.stringify(data));
      }
    } catch(e) {}
  });

  // Let the iframe know the parent frame is ready.
  var iframes = document.querySelectorAll('iframe');
  iframes.forEach(function(f) {
    f.contentWindow.postMessage(
      JSON.stringify({ target: 'readyplayerme', type: 'subscribe', eventName: 'v1.avatar.exported' }),
      '*'
    );
  });
})();
''';
