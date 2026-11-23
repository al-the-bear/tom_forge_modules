import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show ForgeFileSession, ForgeSessionFile;
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show ForgeSessionFileFrame;
import 'package:tom_md_editor/tom_md_editor.dart';

import 'forge_md_editor.dart';

/// A Markdown file in Forge's Markdown editor, read and saved through its
/// [ForgeFileSession]: the editor's controller keeps the one history (and
/// the reviews: guarded line edits, CriticMarkup marks, comments), the
/// session the bytes. The editor saves its own file — the application hands
/// it the save and never writes it — and a file changed on disk is not
/// written over.
class ForgeMarkdownFileEditor extends ForgeMdEditor {
  ForgeMarkdownFileEditor({
    required this.session,
    required super.module,
    super.api,
  }) : super(controller: MdEditorController(uri: session.uri)) {
    file = ForgeSessionFile(
      session: session,
      textOf: () {
        controller.flush();
        return controller.markdown;
      },
      adopt: controller.replaceContent,
      markSaved: controller.markSaved,
    );
  }

  /// The file.
  final ForgeFileSession session;

  /// The binding of the controller to the session.
  late final ForgeSessionFile file;

  @override
  Widget buildMain(BuildContext context) =>
      ForgeSessionFileFrame(file: file, child: super.buildMain(context));

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  /// The session saves the file; the application has no text to write.
  @override
  String? getContent() => null;

  /// The application never marks it clean: the save does.
  @override
  void markClean() {}

  @override
  bool replaceContent(String content) {
    file.replaceWith(content);
    return true;
  }

  @override
  Set<String> get supportedActionIds => {
    ...super.supportedActionIds,
    StandardEditingActions.saveActionId,
  };

  @override
  bool isActionEnabled(String actionId) =>
      actionId == StandardEditingActions.saveActionId
      ? file.canSave
      : super.isActionEnabled(actionId);

  @override
  bool executeAction(String actionId) {
    if (actionId != StandardEditingActions.saveActionId) {
      return super.executeAction(actionId);
    }
    if (!file.canSave) return false;
    unawaited(file.save());
    return true;
  }
}
