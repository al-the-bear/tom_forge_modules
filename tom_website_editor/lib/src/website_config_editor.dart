import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'config/website_config_diagnostics.dart';

/// First-class editor for `tom.website-editor.yaml` itself (§6).
///
/// It is **built on the existing `tom_yaml_editor`** ([ForgeYamlEditor]) — YAML
/// syntax, folding, dirty-state, undo/redo, and the save lifecycle all come from
/// that component — and layers website-config semantics on top:
///
/// - **Routing.** [canHandle] accepts *only* the workspace file whose name
///   matches [configFileName] (the §2 naming convention) and rejects everything
///   else, so opening the config routes here while every other YAML/Markdown
///   file (incl. the website's content files) routes to the standard editors.
/// - **Schema + placeholder diagnostics.** On every edit it recomputes
///   [configDiagnostics] via [websiteConfigDiagnostics] — the *same* runtime
///   loader/validator and resolver the registry uses, so editor and runtime
///   agree on validity (single source of truth). The owning module forwards
///   these to the shell diagnostic manager.
/// - **Save → reload.** The shell writes [getContent] to disk and then calls
///   [markClean]; that triggers [onSaveReload], which rebuilds the registry. An
///   invalid document is rejected by the registry, which keeps the last-good
///   config (the reject path lives in `WebsiteEditorController.reload`).
///
/// The YAML controller is created empty by the module; this editor self-loads
/// the on-disk text via [configReader] once (module-contributed editors are not
/// handed file content by the shell), marking the loaded document clean.
class WebsiteConfigEditor extends ForgeYamlEditor {
  WebsiteConfigEditor({
    required super.controller,
    required super.module,
    required this.onSaveReload,
    this.configFileName = 'tom.website-editor.yaml',
    this.configReader,
    this.builtins = const {},
    super.options,
  }) {
    controller.addListener(_recompute);
    _recompute();
    if (configReader != null) {
      unawaited(_load());
    }
  }

  /// Name of the config file this editor handles (matched in [canHandle]).
  final String configFileName;

  /// Rebuilds the registry after a save (§6 "save → reload"). Returns whether
  /// the new config was applied (an invalid config is rejected, last-good kept).
  final Future<bool> Function() onSaveReload;

  /// Reads the on-disk config text for the one-time self-load. When omitted
  /// (tests that seed the controller directly) no self-load runs.
  final Future<String> Function()? configReader;

  /// Host-provided built-in placeholder values (`{port}`, `{browser}`, …) used
  /// when checking whether the document's `{placeholder}` templates resolve.
  final Map<String, String> builtins;

  final ValueNotifier<List<ForgeDiagnostic>> _diagnostics =
      ValueNotifier<List<ForgeDiagnostic>>(const []);
  bool _loaded = false;

  /// Schema + placeholder diagnostics for the current document, recomputed on
  /// every edit. The owning module forwards these to the shell.
  ValueListenable<List<ForgeDiagnostic>> get configDiagnostics => _diagnostics;

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final content = await configReader!();
      controller.setYaml(content);
    } catch (_) {
      // A read failure leaves an empty document; the resulting structural
      // diagnostics tell the author the config is missing/unreadable.
    } finally {
      // The freshly loaded (or empty) document is the on-disk baseline.
      controller.markClean();
    }
  }

  void _recompute() {
    _diagnostics.value = websiteConfigDiagnostics(
      yamlText: controller.yamlText,
      uri: uri,
      builtins: builtins,
    );
  }

  @override
  FileHandlingResult canHandle(Uri uri) {
    final segments = uri.pathSegments;
    final isConfig = segments.isNotEmpty && segments.last == configFileName;
    // Filename-routed: accept only the config file, reject everything else.
    // Returning `inspect` would defer to the inherited
    // ForgeYamlEditor.canHandleContent, which accepts ANY `.yaml` — and since
    // this is a single instance bound to the on-disk config, it would hijack
    // every content `.yaml` opened from the browser. `reject` lets content
    // files route to the standard YAML / Markdown editors (§6 "follow the
    // standard": this editor claims only its own config).
    return isConfig ? FileHandlingResult.accept : FileHandlingResult.reject;
  }

  @override
  String get schemaLabel => 'Website Editor Config';

  @override
  void markClean() {
    super.markClean();
    unawaited(onSaveReload());
  }

  @override
  void dispose() {
    controller.removeListener(_recompute);
    _diagnostics.dispose();
    super.dispose();
  }
}
