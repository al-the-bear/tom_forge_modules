import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';
import '../module/forge_module.dart';
import '../shell/forge_shell_api.dart';
import 'forge_dart_editor.dart';
import 'forge_md_editor.dart';
import 'forge_yaml_editor.dart';

/// The built-in shell module that registers the three editor adapters.
///
/// Usage:
/// ```dart
/// final module = TomForgeShellModule();
/// module.activate(shellApi);
/// ```
class TomForgeShellModule extends ForgeModule {
  final List<ForgeEditor> _editors = [];

  @override
  String get displayName => 'Tom Forge Editors';

  @override
  void activate(ForgeShellApi shell) {
    // Shell reference available for future module-level operations.
  }

  @override
  void deactivate() {
    _editors.clear();
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

  @override
  List<ForgeEditor> get editors => List.unmodifiable(_editors);

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}
