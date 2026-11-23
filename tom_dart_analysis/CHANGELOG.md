# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-23

### Added

- The Dart editor's analysis as a plugin package of `tom_dart_editor`, moved
  out of it with its history: the summary-backed analysis
  (`SummaryBackedDartAnalysisAdapter`, `AnalysisDriverWithPackages`,
  `createAnalysisDriverWithPackages`, `ParsedSummaryModel`,
  `buildAnalysisDriver`), the summary scopes (`SummaryScopeRegistry`,
  `SummaryScope`, `SummaryScopeAsset`, `SummaryAssetBytesLoader`), the
  summary-backed editors (`SummaryBackedDartCodeEditor`,
  `SimpleSummaryBackedDartCodeEditor`, each with a `highlighter` that
  defaults to the semantic one) and the analyzer-based highlighter.
- `DartSyntaxHighlighter` is a `tom_text_highlight` `TokenHighlighter`, given
  to the editor through `DartCodeEditor.highlighter`; its kinds are
  `tokenizeKinds` (the former static `tokenize`), `extractBracketPairs` and
  `findMatchingBracket` stay.
