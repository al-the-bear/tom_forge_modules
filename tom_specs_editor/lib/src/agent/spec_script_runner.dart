import 'package:tom_spec_engine/scripting.dart'
    show
        FileScriptStore,
        ScopeRegistry,
        ScriptRunResult,
        ScriptTools,
        ScriptValidation,
        specScope;

import '../document/spec_document_controller.dart';
import 'engine_spec_controller.dart';

/// The in-process scripting capability the agent drives over the live document
/// (§3, §8.1, plan step 18).
///
/// It links the engine's [ScriptTools] to the editor by registering the `spec`
/// scope against an [EngineSpecController] wrapping the live
/// [SpecDocumentController]. A script run therefore mutates the *same* controller
/// the §8 tools use — no IPC, no second document — so its edits land in the one
/// change log and undo stack (§5).
///
/// Authored scripts persist under `<workspaceRoot>/agent/scripts/` via the
/// engine's [FileScriptStore], keeping them reviewable and re-runnable alongside
/// the document.
class SpecScriptRunner {
  /// Builds the runner over the live [controller], persisting authored scripts
  /// beneath [workspaceRoot].
  SpecScriptRunner({
    required this.controller,
    required String workspaceRoot,
  }) : tools = ScriptTools(
          registry: ScopeRegistry()
            ..register(specScope(EngineSpecController(controller))),
          store: FileScriptStore(workspaceRoot),
        );

  /// The live document controller scripts mutate through.
  final SpecDocumentController controller;

  /// The engine toolset backing `script_author` / `script_validate` /
  /// `script_run` / `script_list` / `script_get` (§8.1).
  final ScriptTools tools;

  /// Runs [source] under the `spec` scope (the §8.1 default), returning the
  /// captured stdout / `main()` result / error. Mutations land on the shared
  /// controller, so the change log and undo reflect them like any tool edit.
  Future<ScriptRunResult> run(
    String source, {
    List<String>? scopes,
    List<Object?>? args,
  }) =>
      tools.run(source: source, scopes: scopes, args: args);

  /// Parses / resolves [source] against the granted scope **without** running
  /// it, returning diagnostics the agent can iterate on (§8.1).
  ScriptValidation validate(String source, {List<String>? scopes}) =>
      tools.validate(source: source, scopes: scopes);
}
