import 'package:tom_spec_engine/scripting.dart' show SpecController;

import '../document/spec_document_controller.dart';

/// Adapts the editor's Flutter [SpecDocumentController] to the engine's
/// pure-Dart [SpecController] port (`llm_and_d4rt_tools.md` §3, plan step 18).
///
/// The engine's `spec` scope binds a script's document API to a
/// [SpecController] — the minimal read + mutation surface it can depend on
/// without pulling in Flutter. The real controller the UI and the
/// `tom_specs_editor_specification.md` §8 tools share is the
/// [SpecDocumentController]; this adapter is the in-process seam that lets a
/// sandboxed D4rt script drive *that same* controller.
///
/// Every method delegates 1:1, so a script edit is indistinguishable from a
/// tool edit: both land on the one controller and therefore in the one change
/// log and undo stack (`llm_and_d4rt_tools.md` §5 "one change log"). No method
/// adds bookkeeping of its own — the controller owns change-log/undo recording
/// — keeping the "one stream of edits" guarantee a structural property, not a
/// convention.
class EngineSpecController implements SpecController {
  /// Binds the engine port to the editor's live [controller].
  EngineSpecController(this.controller);

  /// The live document controller the UI and the
  /// `tom_specs_editor_specification.md` §8 tools also mutate through.
  final SpecDocumentController controller;

  @override
  String? content(String path) => controller.content(path);

  @override
  String? formField(String path, String field) =>
      controller.formField(path, field);

  @override
  List<String> listItems(String listPath) => controller.listItems(listPath);

  @override
  void setContent(String path, String value) =>
      controller.setContent(path, value);

  @override
  void setFormField(String path, String field, String value) =>
      controller.setFormField(path, field, value);

  @override
  String addListItem(String listPath) => controller.addListItem(listPath);

  @override
  bool removeListItem(String itemPath) => controller.removeListItem(itemPath);

  @override
  String addChild(String parentPath, String childSegment, {String? itemId}) =>
      controller.addChild(parentPath, childSegment, itemId: itemId);
}
