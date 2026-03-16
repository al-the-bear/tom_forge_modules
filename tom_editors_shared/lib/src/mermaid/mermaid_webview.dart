import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

/// Mermaid theme options matching the official mermaid.js themes.
enum MermaidTheme {
  /// Light theme (default).
  light('default'),

  /// Dark theme.
  dark('dark'),

  /// Neutral grey theme.
  neutral('neutral'),

  /// Green forest theme.
  forest('forest');

  const MermaidTheme(this.jsName);

  /// The theme name as expected by mermaid.js `initialize()`.
  final String jsName;
}

/// Renders a Mermaid diagram using the official mermaid.js library in a
/// WebView, providing full-fidelity rendering of all diagram types.
///
/// Each instance creates a small WebView that loads the mermaid.js library
/// and renders the diagram source. The widget auto-sizes its height to fit
/// the rendered diagram.
///
/// Supported diagram types include flowchart, sequence, class, state, ER,
/// pie, gantt, timeline, kanban, mindmap, xychart, radar, gitGraph,
/// journey, quadrant, and any future types added to mermaid.js.
class MermaidWebView extends StatefulWidget {
  const MermaidWebView({
    super.key,
    required this.source,
    this.theme = MermaidTheme.light,
    this.backgroundColor,
    this.onError,
    this.minHeight = 60,
    this.maxHeight = 2000,
  });

  /// The Mermaid diagram source code (without fence markers).
  final String source;

  /// The mermaid rendering theme.
  final MermaidTheme theme;

  /// Background color for the diagram area. Defaults to white/transparent.
  final Color? backgroundColor;

  /// Called when mermaid.js fails to render the diagram.
  final ValueChanged<String>? onError;

  /// Minimum height before auto-sizing kicks in.
  final double minHeight;

  /// Maximum allowed height to prevent unbounded growth.
  final double maxHeight;

  @override
  State<MermaidWebView> createState() => _MermaidWebViewState();
}

class _MermaidWebViewState extends State<MermaidWebView> {
  WebViewController? _controller;
  double _height = 200;
  bool _loading = true;
  bool _pageReady = false;
  bool _platformAvailable = true;
  String? _error;

  /// Cached mermaid.min.js source loaded once from the bundled asset.
  static String? _mermaidJs;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didUpdateWidget(MermaidWebView old) {
    super.didUpdateWidget(old);
    final bgChanged = old.backgroundColor != widget.backgroundColor;
    if (bgChanged) {
      _updateBackground();
    }
    if (old.source != widget.source || old.theme != widget.theme || bgChanged) {
      _renderDiagram();
    }
  }

  /// Update the HTML body background via JavaScript when the Flutter
  /// background color changes (e.g. dark ↔ light theme switch).
  void _updateBackground() {
    if (_controller == null) return;
    final bgColor = widget.backgroundColor ?? Colors.white;
    final r = (bgColor.r * 255.0).round().clamp(0, 255);
    final g = (bgColor.g * 255.0).round().clamp(0, 255);
    final b = (bgColor.b * 255.0).round().clamp(0, 255);
    final hex =
        '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
    _controller!.runJavaScript('document.body.style.background=${jsonEncode(hex)};');
  }

  Future<void> _initWebView() async {
    try {
      // Load mermaid.js from bundled asset once and cache it.
      _mermaidJs ??= await rootBundle.loadString(
        'packages/tom_editors_shared/assets/js/mermaid.min.js',
      );

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'MermaidChannel',
          onMessageReceived: _onMessage,
        )
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            _pageReady = true;
            _renderDiagram();
          },
        ));

      // setBackgroundColor is not implemented on macOS WKWebView —
      // ignore the error so the WebView still initialises.
      try {
        controller
            .setBackgroundColor(widget.backgroundColor ?? Colors.white);
      } catch (_) {
        // Silently ignored; the HTML body background handles the color.
      }

      // Assign the controller before loading HTML so that
      // onPageFinished → _renderDiagram can use it immediately.
      _controller = controller;
      if (mounted) setState(() {});

      await controller.loadHtmlString(_buildHtml(_mermaidJs!));
    } catch (e, st) {
      // WebView platform not available (e.g. in tests) or asset missing.
      debugPrint('[MermaidWebView] init failed: $e\n$st');
      if (mounted) {
        setState(() {
          _platformAvailable = false;
          _loading = false;
        });
      }
    }
  }

  void _onMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message) as Map<String, dynamic>;
    final type = data['type'] as String;

    if (type == 'rendered') {
      final height = (data['height'] as num).toDouble();
      if (mounted) {
        setState(() {
          _height = height.clamp(widget.minHeight, widget.maxHeight);
          _loading = false;
          _error = null;
        });
      }
    } else if (type == 'error') {
      final msg = data['message'] as String;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = msg;
        });
      }
      widget.onError?.call(msg);
    }
  }

  void _renderDiagram() {
    if (!_pageReady || _controller == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    // JSON-encode the source to safely pass it into JavaScript,
    // preventing injection of arbitrary JS through diagram source.
    final escapedSource = jsonEncode(widget.source);
    final themeName = widget.theme.jsName;
    _controller!.runJavaScript(
      'renderMermaid($escapedSource, ${jsonEncode(themeName)});',
    );
  }

  String _buildHtml(String mermaidJs) {
    final bgColor = widget.backgroundColor ?? Colors.white;
    final r = (bgColor.r * 255.0).round().clamp(0, 255);
    final g = (bgColor.g * 255.0).round().clamp(0, 255);
    final b = (bgColor.b * 255.0).round().clamp(0, 255);
    final bgHex =
        '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';

    final isDark = widget.theme == MermaidTheme.dark;

    return '''<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<script>$mermaidJs</script>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:$bgHex;font-family:sans-serif}
#diagram{padding:8px}
#diagram svg{display:block;max-width:100%;height:auto}
.error{color:#d32f2f;font-family:monospace;font-size:12px;padding:8px}
${isDark ? '''
/* Dark-mode fix: ensure mindmap text is visible on dark nodes. */
.mindmap-node>div{color:#e0e0e0!important}
.mindmap-node rect,.mindmap-node circle,.mindmap-node polygon{stroke:#888!important}
''' : ''}
</style>
</head><body>
<div id="diagram"></div>
<script>
let rc=0;
async function renderMermaid(source,theme){
  const c=document.getElementById('diagram');
  rc++;
  const id='m'+rc;
  try{
    const t=theme||'default';
    mermaid.initialize({startOnLoad:false,theme:t,securityLevel:'loose'});
    const{svg}=await mermaid.render(id,source);
    c.innerHTML=svg;
    // Wait for the SVG to layout, then measure its actual dimensions.
    requestAnimationFrame(()=>{
      requestAnimationFrame(()=>{
        const s=c.querySelector('svg');
        let w=0,h=0;
        if(s){
          const r=s.getBoundingClientRect();
          w=Math.ceil(r.width);
          h=Math.ceil(r.height);
        }
        // Fall back to container scroll dimensions if SVG rect is empty.
        if(h<1){h=c.scrollHeight}
        if(w<1){w=c.scrollWidth}
        // Add padding (8px on each side).
        MermaidChannel.postMessage(JSON.stringify({
          type:'rendered',
          width:w+16,
          height:h+16
        }));
      });
    });
  }catch(e){
    c.innerHTML='<div class="error">'+
      (e.message||String(e)).replace(/</g,'&lt;')+'</div>';
    MermaidChannel.postMessage(JSON.stringify({
      type:'error',
      message:e.message||String(e)
    }));
  }
}
</script>
</body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    if (!_platformAvailable || _error != null) {
      return _buildErrorFallback();
    }

    // Controller not yet ready (async init in progress) — show loading.
    if (_controller == null) {
      return SizedBox(
        width: double.infinity,
        height: widget.minHeight,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: Stack(
        children: [
          // IgnorePointer lets scroll and other gestures pass through
          // to the parent ListView, since rendered diagrams are static.
          IgnorePointer(
            child: WebViewWidget(
              controller: _controller!,
              gestureRecognizers: const <Factory<
                  OneSequenceGestureRecognizer>>{},
            ),
          ),
          if (_loading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorFallback() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                'Diagram render failed',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            widget.source,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
