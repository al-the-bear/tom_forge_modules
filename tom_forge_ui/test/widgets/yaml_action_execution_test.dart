import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show EditorCapabilities, EditorStateSnapshot, StandardEditingActions;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  group('YAML editor undo/redo routing', () {
    late DefaultShellApi shellApi;
    late DefaultSystemState systemState;
    late _MockYamlEditor editor;

    setUp(() {
      shellApi = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test Shell',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      systemState = shellApi.systemState as DefaultSystemState;
      editor = _MockYamlEditor();
      systemState.addOpenEditor(editor);
      systemState.setActiveEditor(editor);
    });

    test('01: undo action goes to active YAML editor', () {
      editor.canUndoValue = true;
      var called = false;
      editor.registerActionHandler(
        StandardEditingActions.undoActionId,
        () => called = true,
      );

      final result = shellApi.executeAction(StandardEditingActions.undoActionId);

      expect(result, isTrue);
      expect(called, isTrue);
    });

    test('02: redo action goes to active YAML editor', () {
      editor.canRedoValue = true;
      var called = false;
      editor.registerActionHandler(
        StandardEditingActions.redoActionId,
        () => called = true,
      );

      final result = shellApi.executeAction(StandardEditingActions.redoActionId);

      expect(result, isTrue);
      expect(called, isTrue);
    });

    test('03: undo blocked when canUndo=false', () {
      editor.canUndoValue = false;

      final result = shellApi.executeAction(StandardEditingActions.undoActionId);

      expect(result, isFalse);
    });

    test('04: editor supports undo/redo IDs in non-text mode', () {
      expect(
        editor.supportedActionIds,
        contains(StandardEditingActions.undoActionId),
      );
      expect(
        editor.supportedActionIds,
        contains(StandardEditingActions.redoActionId),
      );
    });
  });
}

class _MockYamlEditor extends ForgeEditor {
  final _title = ValueNotifier<String>('test.yaml');
  final _titleExtension = ValueNotifier<String?>(null);
  final _dirty = ValueNotifier<bool>(false);

  bool canUndoValue = false;
  bool canRedoValue = false;
  final Map<String, VoidCallback> _handlers = {};

  void registerActionHandler(String actionId, VoidCallback handler) {
    _handlers[actionId] = handler;
  }

  @override
  Uri get uri => Uri.parse('file:///test.yaml');

  @override
  ValueNotifier<String> get title => _title;

  @override
  ValueNotifier<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.description;

  @override
  ValueNotifier<bool> get isDirty => _dirty;

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  void markClean() {
    _dirty.value = false;
  }

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const SizedBox.shrink();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox.shrink();

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
  };

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
    hasTextBuffer: false,
    supportsUndoRedo: true,
    supportsClipboard: false,
    supportsLineEditing: false,
    supportsSelection: false,
  );

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
    hasSelection: false,
    hasContent: true,
    isEditable: true,
    canUndo: canUndoValue,
    canRedo: canRedoValue,
    isTextMode: false,
  );

  @override
  bool executeAction(String actionId) {
    final h = _handlers[actionId];
    if (h == null) return false;
    h();
    return true;
  }

  @override
  Stream<void> get onStateChanged => const Stream.empty();
}
