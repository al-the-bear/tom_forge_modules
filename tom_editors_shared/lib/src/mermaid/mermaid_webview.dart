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
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = data['type'] as String?;
    if (type == null) return;

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
    } else if (type == 'scroll') {
      final deltaY = (data['deltaY'] as num).toDouble();
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        final pos = scrollable.position;
        pos.jumpTo(
          (pos.pixels + deltaY).clamp(
            pos.minScrollExtent,
            pos.maxScrollExtent,
          ),
        );
      }
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

    return '''<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<script>$mermaidJs</script>
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{overflow:hidden;background:$bgHex;font-family:sans-serif}
#diagram{padding:8px}
#diagram svg{display:block;max-width:100%;height:auto}
.error{color:#d32f2f;font-family:monospace;font-size:12px;padding:8px}
/* Dark-mode CSS overrides — activated via body.dark class.
   Used for Gantt (rendered with default theme for correct viewBox)
   and as reinforcement for other dark-theme diagrams. */
body.dark #diagram .section,
body.dark #diagram .section0,
body.dark #diagram .section1,
body.dark #diagram .section2,
body.dark #diagram .section3{fill:#2d2d2d !important}
body.dark #diagram .task,
body.dark #diagram .task0,
body.dark #diagram .task1,
body.dark #diagram .task2,
body.dark #diagram .task3{fill:#4a5a8a !important;stroke:#667 !important}
body.dark #diagram .taskText,
body.dark #diagram .taskText0,
body.dark #diagram .taskText1,
body.dark #diagram .taskText2,
body.dark #diagram .taskText3,
body.dark #diagram .taskTextOutsideLeft,
body.dark #diagram .taskTextOutsideRight,
body.dark #diagram .taskTextOutside0,
body.dark #diagram .taskTextOutside1,
body.dark #diagram .taskTextOutside2,
body.dark #diagram .taskTextOutside3{fill:#e0e0e0 !important}
body.dark #diagram .titleText{fill:#e0e0e0 !important}
body.dark #diagram .sectionTitle,
body.dark #diagram .sectionTitle0,
body.dark #diagram .sectionTitle1,
body.dark #diagram .sectionTitle2,
body.dark #diagram .sectionTitle3{fill:#e0e0e0 !important}
body.dark #diagram .tick text{fill:#b0b0b0 !important}
body.dark #diagram .grid .tick line{stroke:#555 !important}
body.dark #diagram .domain{stroke:#666 !important}
body.dark #diagram .today{stroke:#ff6666 !important;stroke-width:2px !important}
body.dark #diagram .done{fill:#2a5a2a !important;stroke:#696 !important}
body.dark #diagram .active{fill:#5a5a9a !important;stroke:#88a !important}
body.dark #diagram .crit{fill:#6a3a3a !important;stroke:#966 !important}
body.dark #diagram .activeCrit{fill:#6a3a3a !important;stroke:#966 !important}
body.dark #diagram .mindmap-node text{fill:#e0e0e0 !important}
body.dark #diagram .mindmap-node foreignObject span,
body.dark #diagram .mindmap-node foreignObject div{color:#e0e0e0 !important}
</style>
</head><body>
<div id="diagram"></div>
<script>

let rc=0;
function parseViewBox(svg){
  if(!svg){return {w:0,h:0,text:'none'}};
  var vb=svg.getAttribute('viewBox')||'none';
  if(vb==='none'){return {w:0,h:0,text:vb}};
  var p=vb.trim().split(/\\s+/).map(Number);
  if(p.length<4||Number.isNaN(p[2])||Number.isNaN(p[3])){
    return {w:0,h:0,text:vb};
  }
  return {w:Math.max(0,p[2]),h:Math.max(0,p[3]),text:vb};
}

function measureDiagram(c){
  var s=c.querySelector('svg');
  var r=s?s.getBoundingClientRect():{width:0,height:0};
  var vb=parseViewBox(s);
  var sw=Math.ceil(s?Number(s.getAttribute('width')||0):0);
  var sh=Math.ceil(s?Number(s.getAttribute('height')||0):0);
  var width=Math.max(
    Math.ceil(r.width||0),
    vb.w,
    sw,
    Math.ceil(c.scrollWidth||0),
    Math.ceil(document.body.scrollWidth||0),
    Math.ceil(document.documentElement.scrollWidth||0)
  );
  var height=Math.max(
    Math.ceil(r.height||0),
    vb.h,
    sh,
    Math.ceil(c.scrollHeight||0),
    Math.ceil(document.body.scrollHeight||0),
    Math.ceil(document.documentElement.scrollHeight||0)
  );
  return {
    svg:s,
    viewBox:vb.text,
    viewBoxWidth:vb.w,
    viewBoxHeight:vb.h,
    width:width,
    height:height
  };
}

function postRendered(c,isGantt,renderTheme){
  var m=measureDiagram(c);
  MermaidChannel.postMessage(JSON.stringify({
    type:'rendered',
    width:Math.max(32,m.width+16),
    height:Math.max(32,m.height+16),
    diag:{
      isGantt:isGantt,
      renderTheme:renderTheme,
      viewBox:m.viewBox,
      w:m.width,
      h:m.height
    }
  }));
  return m;
}

async function renderMermaid(source,theme,attempt){
  attempt=attempt||0;
  const c=document.getElementById('diagram');
  const isDark=(theme==='dark');
  // Toggle body class so the <head> CSS dark overrides activate.
  document.body.className=isDark?'dark':'';
  const isGantt=source.trim().split('\\n')[0].trim().toLowerCase()==='gantt';
  // Mermaid v11 Gantt bug: first render in a fresh WebView produces
  // zero-width viewBox because mermaid reads container width before
  // layout. Workaround: do a throwaway render to warm up the container,
  // then immediately re-render for real.
  if(isGantt){
    rc++;
    try{
      mermaid.initialize({startOnLoad:false,theme:'default',securityLevel:'loose'});
      var warm=await mermaid.render('warmup'+rc,source);
      c.innerHTML=warm.svg;
    }catch(e){}
    // Allow one layout pass so the container gets real dimensions.
    await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
  }
  rc++;
  const id='m'+rc;
  try{
    const renderTheme=theme||'default';
    var cfg={startOnLoad:false,theme:renderTheme,securityLevel:'loose'};
    if(isDark){
      cfg.themeVariables={
        sectionBkgColor:'#2d2d2d',altSectionBkgColor:'#363636',
        taskBkgColor:'#3a3a6a',activeTaskBkgColor:'#4a4a7a',
        doneTaskBkgColor:'#2a5a2a',critBkgColor:'#6a2a2a',
        taskTextColor:'#e0e0e0',taskTextOutsideColor:'#e0e0e0',
        taskTextDarkColor:'#e0e0e0',
        gridColor:'#444444',todayLineColor:'#ff6666',
        titleColor:'#e0e0e0',sectionTitleColor:'#e0e0e0'
      };
    }
    mermaid.initialize(cfg);
    const{svg}=await mermaid.render(id,source);
    c.innerHTML=svg;
    // Post-render dark-theme DOM fixes.
    if(isDark){
      c.querySelectorAll('.mindmap-node text, .mindmap-node foreignObject span, .mindmap-node foreignObject div').forEach(function(el){
        el.style.setProperty('color','#e0e0e0','important');
        el.style.setProperty('fill','#e0e0e0','important');
      });
      c.querySelectorAll('.taskText, .taskTextOutsideRight, .taskTextOutsideLeft, .titleText, .sectionTitle').forEach(function(el){
        el.style.setProperty('fill','#e0e0e0','important');
      });
      c.querySelectorAll('.tick text').forEach(function(el){
        el.style.setProperty('fill','#b0b0b0','important');
      });
      c.querySelectorAll('.task').forEach(function(el){
        if(!el.style.fill || el.style.fill==='none'){
          el.style.setProperty('fill','#3a3a6a','important');
        }
      });
      c.querySelectorAll('.section0,.section1,.section2,.section3').forEach(function(el){
        var cur=el.getAttribute('fill')||el.style.fill||'';
        if(!cur||cur==='#ffffff'||cur==='white'||cur==='#fff'){
          el.style.setProperty('fill','#2d2d2d','important');
        }
      });
      c.querySelectorAll('.grid .tick line').forEach(function(el){
        el.style.setProperty('stroke','#444','important');
      });
    }
    // Wait for layout, then measure with retries when dimensions are unstable.
    await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
    var m=postRendered(c,isGantt,renderTheme);
    var zeroOrTiny=m.width<32||m.height<32;
    var invalidGantt=isGantt&&(m.viewBoxWidth<1||m.viewBoxHeight<1);
    if((zeroOrTiny||invalidGantt)&&attempt<3){
      await new Promise(r=>setTimeout(r,40));
      return renderMermaid(source,theme,attempt+1);
    }

    // Send one more stabilized size after the browser settles late layout.
    setTimeout(function(){postRendered(c,isGantt,renderTheme);},80);
  }catch(e){
    c.innerHTML='<div class="error">'+
      (e.message||String(e)).replace(/</g,'&lt;')+'</div>';
    MermaidChannel.postMessage(JSON.stringify({
      type:'error',
      message:e.message||String(e)
    }));
  }
}
// Forward wheel events to Flutter so the parent ScrollView can scroll.
document.addEventListener('wheel',function(e){
  e.preventDefault();
  var dy=e.deltaY;
  if(e.deltaMode===1)dy*=16;
  if(e.deltaMode===2)dy*=window.innerHeight;
  MermaidChannel.postMessage(JSON.stringify({type:'scroll',deltaX:e.deltaX,deltaY:dy}));
},{passive:false,capture:true});
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
          WebViewWidget(
            controller: _controller!,
            gestureRecognizers: const <Factory<
                OneSequenceGestureRecognizer>>{},
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
