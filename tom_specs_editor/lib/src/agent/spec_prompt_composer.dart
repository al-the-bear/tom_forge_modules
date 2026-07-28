// SpecPromptComposer — the `tom_specs_editor_specification.md` §11.5
// placeholder resolution context.
//
// Wires `tom_core_agentic`'s placeholder engine into the editor's send path
// (`tom_specs_editor_specification.md` §11.5). A composed prompt has its
// `${name}` / `{{name}}` / `${env:NAME}` placeholders expanded; the
// `${{ … }}` expression form is deliberately *disabled* — encountering it
// throws [PlaceholderExpressionsUnsupportedError] rather than executing any
// code (the editor has no d4rt evaluator and must never run untrusted
// expressions).
//
// Resolution context (`tom_specs_editor_specification.md` §11.5 P1): the
// **quest = workspace name**, and file-injection placeholders resolve against
// that workspace's `_ai/` folder — the folder that also holds the
// specification. This composer supplies:
//   * built-in scalar bindings — `date`, `time`, `quest` (= workspace name),
//     `role`, plus the host-context `chat` (current transcript) and `file`
//     (active document), both lenient-empty until the host wires a provider;
//   * the user's custom chat variables (`tom_specs_editor_specification.md`
//     §11.4); and
//   * namespaced file-injection tokens (missing files render empty in lenient
//     mode), matching the VS Code extension's folder conventions:
//       - `${file-<relpath>}`    — read from under the `_ai/` folder;
//       - `${guidelines-<name>}` — `<workspace>/_copilot_guidelines/<name>.md`
//         (fallback `_guidelines/<name>.md`); `<name>` may carry `.md`;
//       - `${role-<name>}`       — `<_ai>/roles/<name>.md` (fallback
//         `<_ai>/roles/<name>/role.md`);
//       - `${quest-<type>}` — the first `<_ai>/quests/<quest>/<type>.<quest>.*`
//         match, where the quest is the workspace name
//         (`tom_specs_editor_specification.md` §11.5 P1).
//
// SDK-owned concepts the Agent SDK manages itself (notably `${memory}`) are
// simply not used here, and a single capability level applies
// (`tom_specs_editor_specification.md` §11.5 P2).
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
    String Function()? chatTranscript,
    String Function()? activeDocument,
  })  : aiFolder = aiFolder ?? Directory('${Directory.current.path}/_ai'),
        _variables = List<ChatVariable>.unmodifiable(variables),
        _clock = clock ?? DateTime.now,
        _chatTranscript = chatTranscript ?? _empty,
        _activeDocument = activeDocument ?? _empty;

  /// The quest name (`tom_specs_editor_specification.md` §11.5 P1) — the Forge
  /// process's workspace folder name. Bound to the `${quest}` placeholder.
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

  /// Host-context providers (`tom_specs_editor_specification.md` §11.5, OE-12):
  /// the current chat transcript and the active document rendered as text. Both
  /// default to lenient-empty — when the host has not wired the context,
  /// `${chat}` / `${file}` resolve to `''` rather than failing the compose.
  final String Function() _chatTranscript;
  final String Function() _activeDocument;

  /// The composer-supplied built-ins for [now], flagged [ChatVariable.builtIn]
  /// so the chat-variables editor (`tom_specs_editor_specification.md` §12) can
  /// render them read-only. The dynamic `chat`/`file` built-ins (OE-12) carry
  /// their current snapshot value, read from the host providers at the moment
  /// this is called.
  List<ChatVariable> builtInsFor(DateTime now) => <ChatVariable>[
        ChatVariable(name: 'date', value: _date(now), builtIn: true),
        ChatVariable(name: 'time', value: _time(now), builtIn: true),
        ChatVariable(name: 'quest', value: workspaceName, builtIn: true),
        ChatVariable(name: 'role', value: role, builtIn: true),
        ChatVariable(name: 'chat', value: _chatTranscript(), builtIn: true),
        ChatVariable(name: 'file', value: _activeDocument(), builtIn: true),
      ];

  /// Expands every supported placeholder in [template].
  ///
  /// Throws [PlaceholderExpressionsUnsupportedError] if the template contains a
  /// `${{ … }}` expression form (`tom_specs_editor_specification.md` §11.5 —
  /// expressions are disabled).
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

  /// The workspace root. Invariant (`tom_specs_editor_specification.md` §11.5
  /// P1): [aiFolder] is the workspace's `_ai/` folder, so its parent is the
  /// workspace root — the base for the `${guidelines-*}` injection, which the
  /// VS Code extension reads from `<workspace>/_copilot_guidelines/` (a sibling
  /// of `_ai/`).
  Directory get _workspaceRoot => aiFolder.parent;

  /// Reads every namespaced file-injection token in [template] and binds each
  /// to its file contents, matching the VS Code extension's folder conventions
  /// (`file-`, `guidelines-`, `role-`, `quest-`). A missing or unreadable file
  /// binds the empty string so the slot renders empty in lenient mode rather
  /// than failing the whole compose.
  Map<String, String> _fileInjections(String template) {
    final out = <String, String>{};
    for (final match in _injectionToken.allMatches(template)) {
      final name = match.group(1)!.trim(); // e.g. guidelines-coding, file-a.md
      if (out.containsKey(name)) continue;
      out[name] = _resolveInjection(name);
    }
    return out;
  }

  /// Dispatches a single injection [name] to the right folder convention.
  String _resolveInjection(String name) {
    if (name.startsWith('guidelines-')) {
      return _readGuidelines(name.substring('guidelines-'.length));
    }
    if (name.startsWith('role-')) {
      return _readRole(name.substring('role-'.length));
    }
    if (name.startsWith('quest-')) {
      return _readQuest(name.substring('quest-'.length));
    }
    // `file-<relpath>` — read from under the `_ai/` folder.
    return _readAiFile(name.substring('file-'.length));
  }

  /// `${guidelines-<name>}` → `<workspace>/_copilot_guidelines/<name>.md`,
  /// falling back to `<workspace>/_guidelines/<name>.md`. `<name>` may already
  /// carry a `.md` suffix (no double extension).
  String _readGuidelines(String rawName) {
    if (rawName.isEmpty) return '';
    final fileName = rawName.endsWith('.md') ? rawName : '$rawName.md';
    final root = _workspaceRoot.path;
    final primary = _readFile('$root/_copilot_guidelines/$fileName');
    if (primary.isNotEmpty) return primary;
    return _readFile('$root/_guidelines/$fileName');
  }

  /// `${role-<name>}` → `<_ai>/roles/<name>.md` (flat), falling back to the
  /// folder layout `<_ai>/roles/<name>/role.md`.
  String _readRole(String rawName) {
    if (rawName.isEmpty) return '';
    final flat = _readFile('${aiFolder.path}/roles/$rawName.md');
    if (flat.isNotEmpty) return flat;
    return _readFile('${aiFolder.path}/roles/$rawName/role.md');
  }

  /// `${quest-<type>}` → the first file under `<_ai>/quests/<quest>/` whose
  /// name starts with `<type>.<quest>.`, where the quest is the workspace name
  /// (`tom_specs_editor_specification.md` §11.5 P1) — e.g. `${quest-overview}`
  /// → `overview.<quest>.md`.
  String _readQuest(String rawType) {
    if (rawType.isEmpty || workspaceName.isEmpty) return '';
    final dir = Directory('${aiFolder.path}/quests/$workspaceName');
    return _readFirstMatching(dir, '$rawType.$workspaceName.');
  }

  String _readAiFile(String relPath) =>
      relPath.isEmpty ? '' : _readFile('${aiFolder.path}/$relPath');

  /// Reads [filePath], returning empty when it is missing or unreadable.
  String _readFile(String filePath) {
    try {
      final file = File(filePath);
      return file.existsSync() ? file.readAsStringSync() : '';
    } on FileSystemException {
      return '';
    }
  }

  /// Returns the contents of the first file directly under [dir] whose name
  /// starts with [prefix], or empty when the directory is missing or nothing
  /// matches.
  String _readFirstMatching(Directory dir, String prefix) {
    try {
      if (!dir.existsSync()) return '';
      for (final entity in dir.listSync()) {
        if (entity is File && entity.uri.pathSegments.last.startsWith(prefix)) {
          return _readFile(entity.path);
        }
      }
      return '';
    } on FileSystemException {
      return '';
    }
  }

  static String _empty() => '';

  static String _date(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  static String _time(DateTime now) =>
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  /// Matches a namespaced file-injection token — `file-`, `guidelines-`,
  /// `role-`, or `quest-` — inside either `${ … }` or `{{ … }}`. The `[^}{]`
  /// body stops before any brace, so a `${{ … }}` expression's inner `{` never
  /// produces a false match (and would be rejected by the resolver regardless).
  /// The scalar built-ins `${role}` / `${quest}` (no trailing dash) are not
  /// matched here.
  static final RegExp _injectionToken =
      RegExp(r'(?:\$\{|\{\{)\s*((?:file|guidelines|role|quest)-[^}{]+?)\s*\}');
}
