/// The YAML editor's source view — the text mode and the subtree inspector —
/// as `tom_file_editors`' source editor ([TomTextSource]) in the editor's
/// theme: its look, its highlighter, and the editing actions it offers to
/// the editor's action integration.
library;

import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeEditorIntegration, StandardEditingActions;
import 'package:tom_file_editors/tom_file_editors.dart'
    show TomTextSourceState, TomTextSourceStyle;

import '../yaml_editor_theme.dart';
import 'yaml_syntax_highlighter.dart';

const List<String> _monoFallback = [
  'JetBrains Mono',
  'Menlo',
  'Monaco',
  'Courier New',
];

/// The source view's look in [theme]: its background, the value colour in
/// the editor's value font size, the line numbers in the hint colour on the
/// surface, a border beside them and the caret's line number drawn brighter.
TomTextSourceStyle yamlSourceStyle(YamlEditorTheme theme) => TomTextSourceStyle(
      background: theme.colors.background,
      textStyle: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: _monoFallback,
        fontSize: theme.fonts.valueFontSize,
        color: theme.colors.valueColor,
        height: 1.4,
      ),
      lineNumberStyle: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: _monoFallback,
        fontSize: theme.fonts.valueFontSize,
        color: theme.colors.hintColor,
        height: 1.4,
      ),
      gutterBackground: theme.colors.surface,
      gutterBorderColor: theme.colors.separatorColor.withAlpha(80),
      cursorColor: Colors.white,
      highlightCurrentLine: true,
    );

/// The YAML highlighter in [theme]'s colours.
YamlSyntaxHighlighter yamlSourceHighlighter(YamlEditorTheme theme) =>
    YamlSyntaxHighlighter(
      colors: YamlHighlightColors(
        key: theme.colors.keyColor,
        string: theme.colors.valueColor,
        number: theme.colors.numberColor,
        boolean: theme.colors.boolColor,
        nullValue: theme.colors.nullColor,
        comment: theme.colors.commentColor,
        punctuation: theme.structureColors.collapseIcon,
        colon: theme.colors.warningColor,
        dash: theme.colors.boolColor,
        bracket: theme.colors.numberColor,
      ),
    );

/// Registers the source view's clipboard and line-editing actions with
/// [integration]: cut, copy, paste, select all, delete, duplicate and move
/// the caret's line, and toggle its comment with [commentPrefix]. Each runs
/// on the source [source] holds while one is shown ([shown]), and is
/// disabled otherwise; [editable] says whether the text may change.
void registerYamlSourceActions(
  ForgeEditorIntegration integration, {
  required GlobalKey<TomTextSourceState> source,
  required bool Function() shown,
  required bool Function() editable,
  String commentPrefix = '# ',
}) {
  TomTextSourceState? current() => shown() ? source.currentState : null;
  bool canEdit() => current() != null && editable();
  bool selected() => current()?.hasSelection ?? false;

  void register(String id, void Function(TomTextSourceState s) run,
          bool Function() enabled) =>
      integration.registerAction(id, () {
        final state = current();
        if (state != null && enabled()) run(state);
      }, isEnabled: enabled);

  register(
    StandardEditingActions.cutActionId,
    (s) => s.cut(),
    () => canEdit() && selected(),
  );
  register(StandardEditingActions.copyActionId, (s) => s.copy(), selected);
  register(StandardEditingActions.pasteActionId, (s) => s.paste(), canEdit);
  register(
    StandardEditingActions.selectAllActionId,
    (s) => s.selectAll(),
    () => current()?.text.isNotEmpty ?? false,
  );
  register(
    StandardEditingActions.deleteLineActionId,
    (s) => s.deleteLine(),
    canEdit,
  );
  register(
    StandardEditingActions.duplicateLineActionId,
    (s) => s.duplicateLine(),
    canEdit,
  );
  register(
    StandardEditingActions.moveLineUpActionId,
    (s) => s.moveLineUp(),
    canEdit,
  );
  register(
    StandardEditingActions.moveLineDownActionId,
    (s) => s.moveLineDown(),
    canEdit,
  );
  register(
    StandardEditingActions.toggleCommentActionId,
    (s) => s.toggleLineComment(prefix: commentPrefix),
    canEdit,
  );
}
