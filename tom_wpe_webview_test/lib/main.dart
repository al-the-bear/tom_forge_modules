import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const ProbeApp());
}

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WPE WebView Probe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const ProbeHomePage(),
    );
  }
}

enum ProbeKind {
  remoteExample,
  inlineHtml,
  inlineSvg,
  localAssetHtml,
  viewportTelemetry,
}

extension ProbeKindMeta on ProbeKind {
  String get label {
    return switch (this) {
      ProbeKind.remoteExample => 'Remote URL: example.com',
      ProbeKind.inlineHtml => 'Inline HTML (loadData)',
      ProbeKind.inlineSvg => 'Inline HTML + SVG',
      ProbeKind.localAssetHtml => 'Local asset HTML',
      ProbeKind.viewportTelemetry => 'Viewport telemetry',
    };
  }
}

class ProbeHomePage extends StatefulWidget {
  const ProbeHomePage({super.key});

  @override
  State<ProbeHomePage> createState() => _ProbeHomePageState();
}

class _ProbeHomePageState extends State<ProbeHomePage> {
  InAppWebViewController? _controller;
  ProbeKind _selected = ProbeKind.remoteExample;
  ProbeKind? _pendingProbe;
  bool _isLoading = false;
  final List<String> _events = <String>[];
  String _status = 'Waiting for WebView...';

  Future<void> _copyLogs() async {
    final text = _events.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Probe logs copied to clipboard')),
    );
  }

  @override
  void initState() {
    super.initState();
    _log('App started');
  }

  void _log(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _events.insert(0, '[$ts] $message');
      if (_events.length > 40) {
        _events.removeRange(40, _events.length);
      }
    });
  }

  Future<void> _loadProbe(ProbeKind kind) async {
    final controller = _controller;
    if (controller == null) return;

    if (_isLoading) {
      _pendingProbe = kind;
      _log('Queued probe while loading: ${kind.label}');
      setState(() {
        _status = 'Queued ${kind.label} (waiting for current load)';
      });
      return;
    }

    _log('Load probe: ${kind.label}');
    setState(() {
      _status = 'Loading ${kind.label}';
    });

    switch (kind) {
      case ProbeKind.remoteExample:
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri('https://example.com')),
        );
      case ProbeKind.inlineHtml:
        await controller.loadData(
          data: _inlineHtmlProbe,
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
      case ProbeKind.inlineSvg:
        await controller.loadData(
          data: _inlineSvgProbe,
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
      case ProbeKind.localAssetHtml:
        final html = await rootBundle.loadString('assets/probe_local.html');
        await controller.loadData(
          data: html,
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
      case ProbeKind.viewportTelemetry:
        await controller.loadData(
          data: _viewportProbe,
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WPE WebView Probe'),
        actions: [
          IconButton(
            tooltip: 'Copy logs',
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy_all),
          ),
          IconButton(
            tooltip: 'Clear logs',
            onPressed: () {
              setState(() {
                _events.clear();
                _status = 'Logs cleared';
              });
            },
            icon: const Icon(Icons.clear_all),
          ),
          IconButton(
            tooltip: 'Reload selected probe',
            onPressed: () => _loadProbe(_selected),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Probe:'),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<ProbeKind>(
                    isExpanded: true,
                    value: _selected,
                    items: ProbeKind.values
                        .map(
                          (probe) => DropdownMenuItem<ProbeKind>(
                            value: probe,
                            child: Text(probe.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selected = value);
                      _loadProbe(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Status: $_status'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyan.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InAppWebView(
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    transparentBackground: false,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                    _log('onWebViewCreated');
                    controller.addJavaScriptHandler(
                      handlerName: 'ProbeChannel',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          _log('ProbeChannel: ${args.first}');
                        }
                        return null;
                      },
                    );
                    _loadProbe(_selected);
                  },
                  onLoadStart: (_, url) {
                    _isLoading = true;
                    _log('onLoadStart: $url');
                    setState(() => _status = 'Load started: $url');
                  },
                  onLoadStop: (controller, url) async {
                    _isLoading = false;
                    _log('onLoadStop: $url');
                    final metrics = await controller.evaluateJavascript(
                      source:
                          'JSON.stringify({w: window.innerWidth, h: window.innerHeight, dpr: window.devicePixelRatio, title: document.title, body: !!document.body});',
                    );
                    setState(() => _status = 'Loaded: $url | metrics=$metrics');
                    _log('viewport metrics: $metrics');

                    final next = _pendingProbe;
                    if (next != null) {
                      _pendingProbe = null;
                      await _loadProbe(next);
                    }
                  },
                  onConsoleMessage: (_, message) {
                    _log('console ${message.messageLevel.name}: ${message.message}');
                  },
                  onReceivedError: (_, request, error) {
                    _isLoading = false;
                    _log('error: ${request.url} -> ${error.description}');
                    setState(() => _status = 'Error: ${error.description}');

                    final next = _pendingProbe;
                    if (next != null) {
                      _pendingProbe = null;
                      _loadProbe(next);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  return SelectableText(
                    _events[index],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

const _inlineHtmlProbe = '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body{margin:0;font-family:Arial;background:linear-gradient(120deg,#111827,#0f172a);color:#e2e8f0}
.card{margin:16px;padding:16px;border:2px solid #22d3ee;border-radius:12px;background:#0b1220}
</style></head>
<body>
  <div class="card">
    <h2>Inline HTML Probe</h2>
    <p>If this renders, loadData HTML works in the webview surface.</p>
  </div>
  <script>
    if (window.flutter_inappwebview?.callHandler) {
      window.flutter_inappwebview.callHandler('ProbeChannel', JSON.stringify({
        type:'inline-html', w:window.innerWidth, h:window.innerHeight
      }));
    }
  </script>
</body></html>''';

const _inlineSvgProbe = '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#020617;">
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="260" viewBox="0 0 800 260">
  <rect width="800" height="260" fill="#0f172a"/>
  <rect x="16" y="16" width="768" height="228" rx="12" fill="#111827" stroke="#38bdf8" stroke-width="2"/>
  <circle cx="70" cy="90" r="24" fill="#22c55e"/><circle cx="130" cy="90" r="24" fill="#f59e0b"/><circle cx="190" cy="90" r="24" fill="#ef4444"/>
  <text x="240" y="92" font-size="34" fill="#e2e8f0" font-family="Arial">Inline SVG Probe</text>
  <text x="240" y="128" font-size="18" fill="#93c5fd" font-family="Arial">If visible, SVG in the webview renders.</text>
</svg>
<script>
  if (window.flutter_inappwebview?.callHandler) {
    window.flutter_inappwebview.callHandler('ProbeChannel', JSON.stringify({
      type:'inline-svg', w:window.innerWidth, h:window.innerHeight
    }));
  }
</script>
</body></html>''';

const _viewportProbe = '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#111827;color:#e5e7eb;font-family:monospace">
<pre id="out" style="padding:12px"></pre>
<script>
  function report(tag){
    const data={
      type:'viewport',
      tag:tag,
      innerWidth:window.innerWidth,
      innerHeight:window.innerHeight,
      outerWidth:window.outerWidth,
      outerHeight:window.outerHeight,
      dpr:window.devicePixelRatio,
      bodyW:document.body?document.body.clientWidth:null,
      bodyH:document.body?document.body.clientHeight:null
    };
    document.getElementById('out').textContent=JSON.stringify(data,null,2);
    if(window.flutter_inappwebview?.callHandler){
      window.flutter_inappwebview.callHandler('ProbeChannel', JSON.stringify(data));
    }
  }
  report('initial');
  window.addEventListener('resize',()=>report('resize'));
</script>
</body></html>''';
