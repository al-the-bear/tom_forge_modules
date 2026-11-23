import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_dart_editor.dart';

/// Outline provider for Dart source files.
///
/// Performs lightweight regex-based scanning to extract class, mixin,
/// enum, extension, and top-level function declarations.  This is not
/// a full Dart parser — it provides a useful structural overview that
/// directly connects to the Dart editor adapter.
class DartOutlineProvider implements ForgeOutlineProvider {
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  @override
  bool canProvide(ForgeEditor editor) => editor is ForgeDartEditor;

  @override
  Future<List<ForgeOutlineItem>> provideOutline(ForgeEditor editor) async {
    if (editor is! ForgeDartEditor) return [];
    final code = editor.getContent() ?? '';
    return _parseOutline(code);
  }

  @override
  Stream<void> get onDidChange => _changeController.stream;

  /// Notify listeners that outline data may have changed.
  void invalidate() => _changeController.add(null);

  /// Release resources.
  void dispose() => _changeController.close();

  // ── Parsing ──

  /// Top-level declaration patterns.
  static final _classPattern = RegExp(
    r'^(abstract\s+)?(class|mixin|enum|extension)\s+(\w+)',
    multiLine: true,
  );
  static final _functionPattern = RegExp(
    r'^(\w[\w<>,\s\?]*)\s+(\w+)\s*\(',
    multiLine: true,
  );

  List<ForgeOutlineItem> _parseOutline(String code) {
    final items = <ForgeOutlineItem>[];
    final lines = code.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      // Skip comments and empty lines.
      if (trimmed.isEmpty ||
          trimmed.startsWith('//') ||
          trimmed.startsWith('*')) {
        continue;
      }

      // Skip import/export/part/library directives.
      if (trimmed.startsWith('import ') ||
          trimmed.startsWith('export ') ||
          trimmed.startsWith('part ') ||
          trimmed.startsWith('library ')) {
        continue;
      }

      // Class, mixin, enum, extension.
      final classMatch = _classPattern.firstMatch(trimmed);
      if (classMatch != null) {
        final keyword = classMatch.group(2)!;
        final name = classMatch.group(3)!;
        final kind = switch (keyword) {
          'class' => ForgeSymbolKind.classKind,
          'mixin' => ForgeSymbolKind.interface,
          'enum' => ForgeSymbolKind.enumKind,
          'extension' => ForgeSymbolKind.namespace,
          _ => ForgeSymbolKind.classKind,
        };
        final isAbstract = classMatch.group(1) != null;
        final col = line.indexOf(name);
        items.add(
          ForgeOutlineItem(
            label: name,
            kind: kind,
            detail: isAbstract ? 'abstract $keyword' : keyword,
            range: ForgeTextRange(
              start: ForgeTextPosition(line: i, column: 0),
              end: ForgeTextPosition(line: i, column: line.length),
            ),
            selectionRange: ForgeTextRange(
              start: ForgeTextPosition(line: i, column: col),
              end: ForgeTextPosition(line: i, column: col + name.length),
            ),
          ),
        );
        continue;
      }

      // Top-level functions (only lines at column 0 indentation).
      if (line.isNotEmpty && line[0] != ' ' && line[0] != '\t') {
        final funcMatch = _functionPattern.firstMatch(trimmed);
        if (funcMatch != null) {
          final returnType = funcMatch.group(1)!.trim();
          final name = funcMatch.group(2)!;
          // Skip common false positives.
          if (const {
            'if',
            'for',
            'while',
            'switch',
            'catch',
            'return',
          }.contains(name)) {
            continue;
          }
          final col = line.indexOf(name);
          items.add(
            ForgeOutlineItem(
              label: name,
              kind: ForgeSymbolKind.function,
              detail: returnType,
              range: ForgeTextRange(
                start: ForgeTextPosition(line: i, column: 0),
                end: ForgeTextPosition(line: i, column: line.length),
              ),
              selectionRange: ForgeTextRange(
                start: ForgeTextPosition(line: i, column: col),
                end: ForgeTextPosition(line: i, column: col + name.length),
              ),
            ),
          );
        }
      }
    }

    return items;
  }
}
