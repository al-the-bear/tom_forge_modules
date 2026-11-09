# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `SummaryBackedDartCodeEditor` no longer re-analyses on every rebuild of its
  host. Without explicit `implicitImports` it compared the old widget's null
  with the new widget's fallback to the controller's imports, so each rebuild
  was a change; a host that rebuilds when the findings arrive analysed for
  ever and never settled.

## [0.1.0] - 2026-02-28

### Added

- Initial release of `tom_dart_editor`
- `DartCodeEditor` widget with full editing capabilities
- `DartCodeController` for managing code state and implicit imports
- `DartEditorTheme` with dark and light presets
- Syntax highlighting with rainbow brackets
- Code completion support with `CompletionItem`
- Error display with tooltips and gutter markers
- Settings toolbar with per-section visibility
- Undo/redo with debounced history
- Auto-indentation and bracket auto-close
- Summary-based analyzer integration for mobile/web
