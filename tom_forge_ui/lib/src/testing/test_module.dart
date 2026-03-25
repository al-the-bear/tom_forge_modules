import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';
import '../module/forge_module.dart';
import '../shell/forge_shell_api.dart';
import 'test_text_editor.dart';

/// A minimal [ForgeModule] for testing the shell integration layer.
///
/// Provides a single [ForgeTestTextEditor] and test actions for
/// exercising the module lifecycle and shell API surface.
class ForgeTestModule extends ForgeModule {
  /// The test text editor instance.
  late final ForgeTestTextEditor testTextEditor;

  /// The shell API, available after [activate].
  ForgeShellApi? api;

  ForgeTestModule() {
    testTextEditor = ForgeTestTextEditor(this);
  }

  @override
  String get displayName => 'Test Module';

  @override
  void activate(ForgeShellApi shell) {
    api = shell;
  }

  @override
  void deactivate() {
    api = null;
  }

  @override
  List<ForgeEditor> get editors => [testTextEditor];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => [
        ForgeAction(
          id: 'test.insertText',
          label: 'Insert Test Text',
          execute: (_) async {
            testTextEditor.insertText('[TEST]');
            return null;
          },
          isEnabled: () => true,
          isVisible: () => true,
        ),
      ];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}
