import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show EditorCapabilities, EditorStateSnapshot, StandardEditingActions;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  group('Action bar and active editor state', () {
    late DefaultShellApi shellApi;
    late DefaultSystemState systemState;
    late _MockEditor editor;

    setUp(() {
      shellApi = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test Shell',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      systemState = shellApi.systemState as DefaultSystemState;
      editor = _MockEditor();
      systemState.addOpenEditor(editor);
      systemState.setActiveEditor(editor);
    });

    tearDown(() {
      editor.dispose();
    });

    test('01: undo is executed when active editor enables it', () {
      var undoCalled = false;
      editor.setCanUndo(true);
      editor.registerActionHandler(
        StandardEditingActions.undoActionId,
        () => undoCalled = true,
      );

      final result = shellApi.executeAction(StandardEditingActions.undoActionId);

      expect(result, isTrue);
      expect(undoCalled, isTrue);
    });

    test('02: undo is blocked when editor reports canUndo=false', () {
      editor.setCanUndo(false);

      final result = shellApi.executeAction(StandardEditingActions.undoActionId);

      expect(result, isFalse);
    });

    test('03: selection-dependent enablement updates correctly', () {
      final copyRule = StandardEditingActions.enablementRule(
        StandardEditingActions.copyActionId,
      );

      editor.setSelection(false);
      expect(copyRule(editor.stateSnapshot), isFalse);

      editor.setSelection(true);
      expect(copyRule(editor.stateSnapshot), isTrue);
    });

    test('04: state stream emits when selection changes', () async {
      final events = <void>[];
      final sub = editor.onStateChanged.listen(events.add);

      editor.setSelection(true);
      await Future<void>.delayed(Duration.zero);
      editor.setSelection(false);
      await Future<void>.delayed(Duration.zero);

      expect(events.length, equals(2));
      await sub.cancel();
    });
  });
}

class _MockEditor extends ForgeEditor {
  final _title = ValueNotifier<String>('test.dart');
  final _titleExtension = ValueNotifier<String?>(null);
  final _dirty = ValueNotifier<bool>(false);
  final _stateController = StreamController<void>.broadcast();
  final Map<String, VoidCallback> _actionHandlers = {};

  bool _hasSelection = false;
  bool _canUndo = false;

  void setSelection(bool hasSelection) {
    _hasSelection = hasSelection;
    _stateController.add(null);
  }

  void setCanUndo(bool canUndo) {
    _canUndo = canUndo;
    _stateController.add(null);
  }

  void registerActionHandler(String actionId, VoidCallback handler) {
    _actionHandlers[actionId] = handler;
  }

  @override
  Uri get uri => Uri.parse('file:///test.dart');

  @override
  ValueNotifier<String> get title => _title;

  @override
  ValueNotifier<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.code;

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
  Set<String> get supportedActionIds => StandardEditingActions.standardActionIds;

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
    hasTextBuffer: true,
    supportsUndoRedo: true,
    supportsClipboard: true,
    supportsLineEditing: true,
    supportsSelection: true,
  );

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
    hasSelection: _hasSelection,
    hasContent: true,
    isEditable: true,
    canUndo: _canUndo,
    canRedo: false,
    isTextMode: true,
  );

  @override
  bool executeAction(String actionId) {
    final handler = _actionHandlers[actionId];
    if (handler == null) return false;
    handler();
    return true;
  }

  @override
  Stream<void> get onStateChanged => _stateController.stream;

  void dispose() {
    _stateController.close();
    _title.dispose();
    _titleExtension.dispose();
    _dirty.dispose();
  }
}
