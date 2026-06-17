// SpecPromptComposer — the §11.5 placeholder resolution context.
//
// Wires `tom_core_agentic`'s placeholder engine into the editor's send path
// (§11.5 of `tom_specs_editor_specification.md`). A composed prompt has its
// `${name}` / `{{name}}` / `${env:NAME}` placeholders expanded; the
// `${{ … }}` expression form is deliberately *disabled* — encountering it
// throws [PlaceholderExpressionsUnsupportedError] rather than executing any
// code (the editor has no d4rt evaluator and must never run untrusted
// expressions).
//
// Resolution context (§11.5 P1): the **quest = workspace name**, and
// file-injection placeholders resolve against that workspace's `_ai/` folder
// — the folder that also holds the specification. This composer supplies:
//   * built-in scalar bindings — `date`, `time`, `quest` (= workspace name),
//     `role`;
//   * the user's custom chat variables (§11.4); and
//   * `${file-<relpath>}` injection — the file's contents read from under the
//     `_ai/` folder (missing files render empty in lenient mode).
//
// SDK-owned concepts the Agent SDK manages itself (notably `${memory}`) are
// simply not used here, and a single capability level applies (§11.5 P2).
library;

import 'dart:io';

import 'package:tom_core_agentic/tom_core_agentic.dart';

/// Composes a final prompt by expanding the editor's supported placeholder
/// forms against the built-ins, the chat variables, and the workspace `_ai/`
/// folder. Stateless apart from its configuration; [compose] is pure given the
/// clock and the filesystem.
class SpecPromptComposer {
  SpecPromptComposer({
    required this.workspaceName,
    Directory? aiFolder,
    List<ChatVariable> variables = const <ChatVariable>[],
    DateTime Function()? clock,
    this.role = '',
    this.strict = false,
  })  : aiFolder = aiFolder ?? Directory('${Directory.current.path}/_ai'),
        _variables = List<ChatVariable>.unmodifiable(variables),
        _clock = clock ?? DateTime.now;

  /// The quest name (§11.5 P1) — the Forge process's workspace folder name.
  /// Bound to the `${quest}` placeholder.
  final String workspaceName;

  /// The workspace's `_ai/` folder, the root `${file-<relpath>}` injections
  /// read from.
  final Directory aiFolder;

  /// The value bound to `${role}`; empty unless the host supplies a role.
  final String role;

  /// When true an unbound `${name}` / `${env:NAME}` throws; the editor's
  /// preview/compose path is lenient (empty) by default.
  final bool strict;

  final List<ChatVariable> _variables;
  final DateTime Function() _clock;

  /// The composer-supplied built-ins for [now], flagged [ChatVariable.builtIn]
  /// so the chat-variables editor (§12) can render them read-only.
  List<ChatVariable> builtInsFor(DateTime now) => <ChatVariable>[
        ChatVariable(name: 'date', value: _date(now), builtIn: true),
        ChatVariable(name: 'time', value: _time(now), builtIn: true),
        ChatVariable(name: 'quest', value: workspaceName, builtIn: true),
        ChatVariable(name: 'role', value: role, builtIn: true),
      ];

  /// Expands every supported placeholder in [template].
  ///
  /// Throws [PlaceholderExpressionsUnsupportedError] if the template contains a
  /// `${{ … }}` expression form (§11.5 — expressions are disabled).
  String compose(String template) {
    final now = _clock();
    final bindings = <String, String>{
      for (final builtIn in builtInsFor(now)) builtIn.name: builtIn.value,
      for (final variable in _variables) variable.name: variable.value,
      ..._fileInjections(template),
    };
    return EditorPlaceholderBindings(bindings: bindings, strict: strict)
        .resolve(template);
  }

  /// Reads the `${file-<relpath>}` / `{{file-<relpath>}}` tokens in [template]
  /// and binds each to the contents of `<aiFolder>/<relpath>`. A missing or
  /// unreadable file binds the empty string so the slot renders empty in
  /// lenient mode rather than failing the whole compose.
  Map<String, String> _fileInjections(String template) {
    final out = <String, String>{};
    for (final match in _fileToken.allMatches(template)) {
      final name = match.group(1)!.trim(); // e.g. file-guidelines/coding.md
      if (out.containsKey(name)) continue;
      final relPath = name.substring('file-'.length);
      out[name] = _readAiFile(relPath);
    }
    return out;
  }

  String _readAiFile(String relPath) {
    try {
      final file = File('${aiFolder.path}/$relPath');
      return file.existsSync() ? file.readAsStringSync() : '';
    } on FileSystemException {
      return '';
    }
  }

  static String _date(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  static String _time(DateTime now) =>
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  /// Matches a `file-<relpath>` token inside either `${ … }` or `{{ … }}`.
  /// The `[^}{]` body stops before any brace, so a `${{ … }}` expression's
  /// inner `{` never produces a false match (and would be rejected by the
  /// resolver regardless).
  static final RegExp _fileToken =
      RegExp(r'(?:\$\{|\{\{)\s*(file-[^}{]+?)\s*\}');
}
