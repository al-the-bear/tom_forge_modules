import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_dart_editor.dart';
import 'dart_editor_configuration.dart';

/// The Dart editor type: `.dart` files in [ForgeDartEditor], reading its
/// analysis summaries where [ForgeDartSummariesByHost] says for the
/// request's host.
///
/// An application takes it with the other editor types it opens files with
/// (the panel shell: `ForgeShellComponents(editorTypes: [...])`).
final ForgeKitEditorType forgeDartEditorType = ForgeKitEditorType(
  id: 'dart',
  label: 'Dart Code Editor',
  description: 'Edit with Dart syntax highlighting',
  extensions: const ['dart'],
  actionDescriptors: DartEditorActions.descriptors,
  configuration: ForgeDartEditorConfiguration.description,
  create: (request) => ForgeDartEditor(
    controller: DartCodeController(
      initialCode: request.content,
      uri: request.uri,
    ),
    module: request.module,
    api: request.api,
    summaries: ForgeDartSummariesByHost.of(request.host),
  ),
);

/// Where the Dart editors an application opens read their analysis
/// summaries, by the host value its editor requests carry
/// ([ForgeKitEditorRequest.host]; the panel shell's is its layout
/// controller): the running app's own assets ([ForgeDartSummaryAssets.root])
/// unless the app is built on a package that carries them.
abstract final class ForgeDartSummariesByHost {
  static final Expando<ForgeDartSummaryAssets> _summaries = Expando(
    'dartSummaryAssets',
  );

  /// The summaries the Dart editors of [host] read; [ForgeDartSummaryAssets.root]
  /// when none were set or there is no host.
  static ForgeDartSummaryAssets of(Object? host) =>
      (host == null ? null : _summaries[host]) ?? ForgeDartSummaryAssets.root;

  /// Sets the summaries the Dart editors of [host] read.
  static void set(Object host, ForgeDartSummaryAssets assets) =>
      _summaries[host] = assets;
}
