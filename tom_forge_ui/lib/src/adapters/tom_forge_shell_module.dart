import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';
import '../module/forge_module.dart';
import '../shell/forge_shell_api.dart';
import 'forge_dart_editor.dart';
import 'forge_md_editor.dart';
import 'forge_yaml_editor.dart';

/// The built-in shell module that registers the editor adapters for
/// known file types (Dart, Markdown, YAML).
///
/// [TomForgeShellModule] owns the default editor adapters and exposes
/// them as typed members.  The [supportedExtensions] getter declares
/// which file extensions are handled at the framework level so that
/// layout controllers can resolve the correct owner module during
/// editor creation.
///
/// Usage:
/// ```dart
/// final module = TomForgeShellModule();
/// module.activate(shellApi);
/// print(module.supportedExtensions); // {dart, md, markdown, yaml, yml, txt}
/// ```
class TomForgeShellModule extends ForgeModule {
  final List<ForgeEditor> _editors = [];
  ForgeShellApi? _shell;

  /// Whether this module has been activated (i.e. [shellApi] is available).
  bool get isActivated => _shell != null;

  ForgeShellApi get shellApi {
    final shell = _shell;
    if (shell == null) {
      throw StateError('TomForgeShellModule has not been activated yet.');
    }
    return shell;
  }

  @override
  String get displayName => 'Tom Forge Editors';

  /// File extensions handled by this module's built-in editor adapters.
  static const Set<String> supportedExtensions = {
    'dart',
    'md',
    'markdown',
    'yaml',
    'yml',
    'txt',
  };

  /// Whether this module handles the given file extension.
  bool canHandleExtension(String ext) =>
      supportedExtensions.contains(ext.toLowerCase());

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
  }

  @override
  void deactivate() {
    _editors.clear();
    _shell = null;
  }

  /// Register a [ForgeMdEditor] adapter and return it.
  ForgeMdEditor registerMdEditor(ForgeMdEditor editor) {
    _editors.add(editor);
    return editor;
  }

  /// Register a [ForgeDartEditor] adapter and return it.
  ForgeDartEditor registerDartEditor(ForgeDartEditor editor) {
    _editors.add(editor);
    return editor;
  }

  /// Register a [ForgeYamlEditor] adapter and return it.
  ForgeYamlEditor registerYamlEditor(ForgeYamlEditor editor) {
    _editors.add(editor);
    return editor;
  }

  /// All registered Dart editors.
  List<ForgeDartEditor> get dartEditors =>
      _editors.whereType<ForgeDartEditor>().toList();

  /// All registered Markdown editors.
  List<ForgeMdEditor> get mdEditors =>
      _editors.whereType<ForgeMdEditor>().toList();

  /// All registered YAML editors.
  List<ForgeYamlEditor> get yamlEditors =>
      _editors.whereType<ForgeYamlEditor>().toList();

  @override
  List<ForgeEditor> get editors => List.unmodifiable(_editors);

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}
