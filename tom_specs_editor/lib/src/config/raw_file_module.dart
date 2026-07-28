import 'dart:io';

import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Opens the backing YAML/markdown file for a config editor
/// (`tom_specs_editor_specification.md` §12, E2).
///
/// Injected into every config editor so the "Open raw file" button is testable
/// without a live shell: production wires it to [RawFileModule.openRawFile]
/// (which routes through the Forge layout), while tests pass a recording stub
/// and assert the opened URI is the editor's backing file.
typedef RawFileOpener = void Function(Uri uri);

/// Hosts the raw-text editing of config files
/// (`tom_specs_editor_specification.md` §12 — the `RawFileModule` the "Open raw
/// file" buttons target, replicating VS Code's `openPanelFile` / `showFile`).
///
/// The config editors edit the object model; their **backing** YAML/markdown is
/// opened here in a plain-text editor. Files are opened on demand: the module
/// reads the file's current bytes and hands a [ForgePlainTextEditor] to the
/// shell layout, which surfaces it in the active middle panel.
class RawFileModule extends ForgeModule {
  RawFileModule();

  ForgeShellApi? _shell;
  final List<ForgeEditor> _editors = [];

  @override
  String get displayName => 'Raw Config Files';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
  }

  @override
  void deactivate() {
    _editors.clear();
    _shell = null;
  }

  /// Opens [uri] (a `file:` URI for a config YAML/markdown) in a plain-text
  /// editor. The file is created empty if it does not yet exist so the editor
  /// always has something to show; the owning config editor normally persists
  /// before calling this, so the current content is already on disk.
  void openRawFile(Uri uri) {
    final shell = _shell;
    if (shell == null) return;
    final file = File.fromUri(uri);
    final content = file.existsSync() ? file.readAsStringSync() : '';
    final editor = ForgePlainTextEditor.fromContent(
      content: content,
      uri: uri,
      module: this,
    );
    _editors.add(editor);
    shell.layout.openEditor(editor, uri);
  }

  @override
  List<ForgeEditor> get editors => List.unmodifiable(_editors);

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}
