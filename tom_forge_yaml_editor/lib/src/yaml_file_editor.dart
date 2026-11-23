import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show ForgeFileSession, ForgeSessionFile;
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show ForgeSessionFileFrame;
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import 'forge_yaml_editor.dart';

/// A YAML file in Forge's YAML editor (tree and source, schema-aware), read
/// and saved through its [ForgeFileSession]: the controller keeps the one
/// history over the source text, the session the bytes. The editor saves its
/// own file, and a file changed on disk is not written over.
class ForgeYamlFileEditor extends ForgeYamlEditor {
  ForgeYamlFileEditor({required this.session, required super.module, super.api})
    : super(controller: YamlEditorController(uri: session.uri)) {
    file = ForgeSessionFile(
      session: session,
      textOf: () => controller.sourceText,
      adopt: controller.replaceContent,
      markSaved: controller.markClean,
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

  @override
  String? getContent() => null;

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
