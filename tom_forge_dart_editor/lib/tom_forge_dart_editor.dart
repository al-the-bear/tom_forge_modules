/// Forge's Dart editor adapter: [ForgeDartEditor] makes the `tom_dart_editor`
/// component a Forge editor over the kit (`tom_forge_kit`),
/// [forgeDartEditorType] is the editor type an application opens `.dart`
/// files with (reading its analysis summaries where
/// [ForgeDartSummariesByHost] says), and [DartOutlineProvider] gives the
/// outline of a Dart editor's code.
library;

export 'src/dart_editor_configuration.dart';
export 'src/dart_editor_type.dart';
export 'src/dart_outline_provider.dart';
export 'src/forge_dart_editor.dart';
