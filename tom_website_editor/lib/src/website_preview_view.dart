import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'website_preview_controller.dart';

/// Builds the embedded preview surface for [url]. [reloadToken] changes on every
/// [WebsitePreviewController.refresh]; the builder uses it as a key so the same
/// URL is reloaded. Injected so widget tests can render a stub instead of the
/// platform webview.
typedef PreviewWebViewBuilder = Widget Function(
  BuildContext context,
  String url,
  int reloadToken,
);

/// Forge view that embeds the active website's preview (dev server or built
/// index) in a webview, with a toolbar to pick the website, toggle the source,
/// reload, and open the URL in an external browser (§4).
///
/// All state lives in the [WebsitePreviewController]; this view only renders it.
/// The controller is owned by the module (created in `activate`, disposed in
/// `deactivate`) — the view does not dispose it.
class WebsitePreviewView extends ForgeView {
  WebsitePreviewView({
    required this.controller,
    PreviewWebViewBuilder? webViewBuilder,
  }) : _webViewBuilder = webViewBuilder ?? _defaultWebViewBuilder;

  /// Drives URL resolution, source toggle, refresh, and external open.
  final WebsitePreviewController controller;

  final PreviewWebViewBuilder _webViewBuilder;

  final _title = ValueNotifier<String>('Preview');
  final _titleExtension = ValueNotifier<String?>(null);

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.public;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        minSize: Size(480, 320),
        preferredSize: Size(720, 520),
      );

  @override
  Widget buildMain(BuildContext context) => _PreviewContent(
        controller: controller,
        webViewBuilder: _webViewBuilder,
        title: _title,
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  @override
  List<ForgeAction> get headerActions => [
        ForgeAction(
          id: 'website-preview.refresh',
          label: 'Reload preview',
          icon: Icons.refresh,
          execute: (_) async {
            controller.refresh();
            return null;
          },
          isEnabled: () => controller.previewUrl != null,
          isVisible: () => true,
        ),
        ForgeAction(
          id: 'website-preview.open-external',
          label: 'Open in external browser',
          icon: Icons.open_in_browser,
          execute: (_) => controller.openInExternalBrowser(),
          isEnabled: () => controller.previewUrl != null,
          isVisible: () => true,
        ),
      ];
}

/// Stateful body that rebuilds when the controller changes and keeps the view's
/// [title] in sync with the active website.
class _PreviewContent extends StatefulWidget {
  const _PreviewContent({
    required this.controller,
    required this.webViewBuilder,
    required this.title,
  });

  final WebsitePreviewController controller;
  final PreviewWebViewBuilder webViewBuilder;
  final ValueNotifier<String> title;

  @override
  State<_PreviewContent> createState() => _PreviewContentState();
}

class _PreviewContentState extends State<_PreviewContent> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _syncTitle();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _syncTitle();
    setState(() {});
  }

  void _syncTitle() {
    final id = widget.controller.activeWebsiteId;
    widget.title.value = id == null ? 'Preview' : 'Preview: $id';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(context),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          if (controller.websites.isNotEmpty)
            DropdownButton<String>(
              value: controller.activeWebsiteId,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final website in controller.websites)
                  DropdownMenuItem(
                    value: website.id,
                    child: Text(website.label ?? website.id),
                  ),
              ],
              onChanged: (id) {
                if (id != null) controller.selectWebsite(id);
              },
            ),
          const SizedBox(width: 12),
          SegmentedButton<WebsitePreviewSource>(
            segments: const [
              ButtonSegment(
                value: WebsitePreviewSource.devUrl,
                label: Text('Dev'),
              ),
              ButtonSegment(
                value: WebsitePreviewSource.builtIndex,
                label: Text('Built'),
              ),
            ],
            selected: {controller.source},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            onSelectionChanged: (selection) =>
                controller.setSource(selection.first),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Reload preview',
            onPressed:
                controller.previewUrl == null ? null : controller.refresh,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, size: 18),
            tooltip: 'Open in external browser',
            onPressed: controller.previewUrl == null
                ? null
                : () => controller.openInExternalBrowser(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = widget.controller;

    final error = controller.resolveError;
    if (error != null) {
      return _PreviewMessage(
        icon: Icons.error_outline,
        title: 'Cannot resolve preview URL',
        detail: '${error.message}\nat ${error.location}',
        isError: true,
      );
    }

    final url = controller.previewUrl;
    if (url == null) {
      final source = controller.source == WebsitePreviewSource.devUrl
          ? 'dev server'
          : 'built index';
      return _PreviewMessage(
        icon: Icons.public_off,
        title: 'No preview available',
        detail: 'The active website has no $source URL configured.',
      );
    }

    return widget.webViewBuilder(context, url, controller.reloadToken);
  }
}

/// Centered icon + message used for the error and empty states.
class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Production webview builder backed by `flutter_inappwebview`. Keyed on
/// `url#reloadToken` so a refresh (or URL change) recreates the platform view.
Widget _defaultWebViewBuilder(
  BuildContext context,
  String url,
  int reloadToken,
) =>
    _PreviewWebView(key: ValueKey('$url#$reloadToken'), url: url);

class _PreviewWebView extends StatelessWidget {
  const _PreviewWebView({super.key, required this.url});

  final String url;

  static bool get _isSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) {
      return _PreviewMessage(
        icon: Icons.public_off,
        title: 'Preview not supported on this platform',
        detail: url,
      );
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
    );
  }
}
