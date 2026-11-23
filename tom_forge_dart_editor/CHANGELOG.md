# Changelog

## Unreleased

- `forgeDartEditorType` carries the editor's own actions
  (`ForgeKitEditorType.actionDescriptors`: `DartEditorActions.descriptors`, now
  the editor package's), which the panel shell lists before an editor is
  open.
- The analysis comes from the Dart editor's plugin `tom_dart_analysis`
  (`SummaryBackedDartAnalysisAdapter`, and `DartSyntaxHighlighter`, given to
  the editor as its highlighter), so Forge's Dart editing is as before:
  summary-backed diagnostics and completions, semantic highlighting.

## 0.1.0

- `ForgeDartEditor` and its editor type `forgeDartEditorType`, moved out of
  `tom_forge_code_editors` with their history. The adapter is built on the
  Forge kit instead of the panel shell: it takes a `ForgeKitModule` (and
  optionally the `ForgeKitApi`) where it took the shell's `ForgeModule`, and
  its type is the kit's `ForgeKitEditorType`.
- `DartOutlineProvider`, and `ForgeDartSummariesByHost`, where the Dart
  editors of a host read their analysis summaries.
