/// A browser over one [MdEditorController]: opens documents, follows links
/// into the workspace, and goes back and forward through the documents
/// visited, returning to where the reader was in each.
///
/// Links to Markdown documents and anchors are followed here; every other
/// link (a file for an editor, a URL, a typed reference, an error) is
/// returned for the host to act on.
library;

import 'package:flutter/foundation.dart';

import '../controller/md_editor_controller.dart';
import 'md_link_resolver.dart';
import 'md_navigation_history.dart';

/// Opens, links and history for a Markdown browser.
class MdBrowserNavigator extends ChangeNotifier {
  MdBrowserNavigator({
    required this.controller,
    required this.resolver,
    required this.read,
    this.workspaceRoot,
    MdNavigationHistory? history,
  }) : history = history ?? MdNavigationHistory();

  /// The document shown.
  final MdEditorController controller;

  final MdLinkResolver resolver;

  /// Reads a document's text.
  final Future<String> Function(String path) read;

  /// The workspace links resolve into.
  final String? workspaceRoot;

  final MdNavigationHistory history;

  String? _anchor;
  MdReadingPosition? _position;

  /// The document shown, or null.
  String? get currentPath => history.current?.filePath;

  bool get canGoBack => history.canGoBack;
  bool get canGoForward => history.canGoForward;

  /// The anchor the view is to scroll to, once; null when none.
  String? takeAnchor() {
    final a = _anchor;
    _anchor = null;
    return a;
  }

  /// The reading position the view is to restore, once (going back or
  /// forward); null when none.
  MdReadingPosition? takePosition() {
    final p = _position;
    _position = null;
    return p;
  }

  /// Shows [path] (scrolled to [anchor]) as a new history entry.
  Future<void> open(String path, {String? anchor, String group = ''}) async {
    await _show(path);
    history.push(MdHistoryEntry(filePath: path, group: group));
    _anchor = anchor;
    notifyListeners();
  }

  /// Reads the document shown again.
  Future<void> reload() async {
    final path = currentPath;
    if (path == null) return;
    await _show(path);
    notifyListeners();
  }

  /// Follows [href] from the document shown. A Markdown document or an anchor
  /// is shown here; the resolved link says what it was either way.
  Future<MdResolvedLink> follow(String href) async {
    final link = resolver.resolve(
      href,
      MdLinkContext(currentFilePath: currentPath, workspaceRoot: workspaceRoot),
    );
    switch (link.action) {
      case MdLinkAction.scrollToAnchor:
        _anchor = link.anchor;
        notifyListeners();
      case MdLinkAction.navigateMd || MdLinkAction.navigateMdAnchor:
        await open(link.filePath!, anchor: link.anchor);
      default:
        break;
    }
    return link;
  }

  /// Remembers where the reader is in the document shown.
  void recordPosition(MdReadingPosition position) {
    final path = currentPath;
    if (path != null) history.recordPosition(path, position);
  }

  /// The previous document, where the reader was in it.
  Future<bool> back() => _step(history.goBack);

  /// The next document, where the reader was in it.
  Future<bool> forward() => _step(history.goForward);

  Future<bool> _step(MdHistoryEntry? Function() move) async {
    final entry = move();
    if (entry == null) return false;
    await _show(entry.filePath);
    _position = entry.position;
    notifyListeners();
    return true;
  }

  Future<void> _show(String path) async {
    final text = await read(path);
    controller.uri = Uri.file(path);
    controller.replaceContent(text);
  }
}
