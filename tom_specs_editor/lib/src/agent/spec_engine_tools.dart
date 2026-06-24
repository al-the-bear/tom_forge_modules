import 'dart:convert';

import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show SpecNodeKind, SpecQuery, SpecQueryEngine, SpecStateFilter;
import 'package:tom_spec_engine/scripting.dart'
    show DocTools, FileTools, ScriptTools, SpecFileFacade;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import '../document/spec_document_controller.dart';
import 'engine_spec_controller.dart';

/// Builds the in-process MCP server exposing the **engine's** §8.2 / §8.1 tool
/// classes (plan step 5 of `d4rt_and_llm_tools_followup.md`).
///
/// Where [SpecAgentTools] exposes the editor's bespoke layer-A/B/C navigation +
/// mutation tools, this server registers the reusable engine toolsets that live
/// in `tom_spec_engine` so the agent reaches the *same* surfaces a headless run
/// would:
///
///   * [DocTools] → `doc_search` / `doc_search_iterate` (the §6 edit-stable
///     cursor), `doc_reflect` (meta-model facts), `doc_add_node` (a
///     meta-model-validated add routed through the one change log);
///   * [FileTools] → `file_read` / `file_find` / `file_write` over the audited
///     read-anywhere / write-whitelist [SpecFileFacade];
///   * [ScriptTools] → `script_author` / `script_validate` / `script_run` /
///     `script_list` / `script_get` over the shared `spec`-scope registry.
///
/// The `mem_*` `MemoryTools` are deliberately **not** registered: they depend on
/// the server-only memory plane (`tom_brain_memory`), which is not in the Flutter
/// compile. Wiring them is followup item 6 (the embeddable memory plane).
///
/// Every handler returns **compact JSON** (`jsonEncode`, no pretty-printing) as a
/// single text content item, mirroring [SpecAgentTools]; the engine result types
/// already carry a `toJson`. Failures set `isError` and carry `{"error": …}`.
class SpecEngineTools {
  /// Binds the toolsets to the shared [controller] (so `doc_add_node` and a
  /// `script_run` mutation land in the one change log), the audited file
  /// [facade], and the shared [scriptTools] (the same instance the editor's
  /// `SpecScriptRunner` drives, so authored scripts share one store).
  SpecEngineTools({
    required this.controller,
    required this.facade,
    required this.scriptTools,
  });

  /// The shared document controller `doc_*` tools read/mutate through.
  final SpecDocumentController controller;

  /// The audited file surface the `file_*` tools operate over.
  final SpecFileFacade facade;

  /// The script toolset backing the `script_*` tools (shared with the runner).
  final ScriptTools scriptTools;

  late final FileTools _fileTools = FileTools(facade);

  /// Lazily built once the model is loaded; cached so the `doc_search` /
  /// `doc_search_iterate` cursor state survives across calls.
  DocTools? _docTools;

  /// Assembles the `McpSdkServerConfig` registered alongside [SpecAgentTools]'s
  /// server into `Options.mcpServers`.
  McpSdkServerConfig buildServer({String name = 'tomspecs-engine'}) =>
      McpSdkServerConfig(
        name: name,
        tools: [
          _docSearch(),
          _docSearchIterate(),
          _docReflect(),
          _docAddNode(),
          _fileRead(),
          _fileFind(),
          _fileWrite(),
          _scriptAuthor(),
          _scriptValidate(),
          _scriptRun(),
          _scriptList(),
          _scriptGet(),
        ],
      );

  // --- result helpers -----------------------------------------------------

  CallToolResult _ok(Object? payload) =>
      CallToolResult.text(jsonEncode(payload));

  CallToolResult _err(String message) =>
      CallToolResult.text(jsonEncode({'error': message}), isError: true);

  String? _str(Map<String, dynamic> args, String key) => args[key]?.toString();

  bool _flag(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return false;
  }

  int? _int(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  List<String>? _strList(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is List) return [for (final e in v) e.toString()];
    if (v is String && v.isNotEmpty) {
      return [for (final e in v.split(',')) e.trim()];
    }
    return null;
  }

  Future<DocTools> _docs() async {
    await controller.ensureLoaded();
    return _docTools ??= DocTools(
      engine: SpecQueryEngine(
        model: controller.model,
        document: controller.document,
      ),
      controller: EngineSpecController(controller),
    );
  }

  // --- doc_* (the §6 query facility + reflection + add) --------------------

  SdkMcpTool _docSearch() => SdkMcpTool(
        name: 'doc_search',
        description:
            'Run a §6 query over the live document and return the first page '
            '(opens a cursor; continue with doc_search_iterate). Every supplied '
            'dimension is AND-combined.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Substring (or regex) to find in content/headline.',
            },
            'regex': {'type': 'boolean'},
            'caseInsensitive': {'type': 'boolean'},
            'kinds': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  'Node kinds to include: root|complex|section|list|form|'
                  'content|scalar.',
            },
            'className': {'type': 'string'},
            'sectionIdExact': {'type': 'string'},
            'sectionIdPrefix': {'type': 'string'},
            'pathGlob': {'type': 'string'},
            'mapsTo': {'type': 'string'},
            'detailedIn': {'type': 'string'},
            'state': {
              'type': 'string',
              'description': 'Value-presence filter: empty|nonEmpty.',
            },
            'pageSize': {'type': 'integer'},
          },
        },
        handler: (args) async {
          final docs = await _docs();
          final Set<SpecNodeKind>? kinds;
          final kindNames = _strList(args, 'kinds');
          if (kindNames == null) {
            kinds = null;
          } else {
            final parsed = <SpecNodeKind>{};
            for (final n in kindNames) {
              final k = SpecNodeKind.values
                  .where((e) => e.name == n)
                  .cast<SpecNodeKind?>()
                  .firstWhere((_) => true, orElse: () => null);
              if (k == null) return _err('Unknown node kind "$n".');
              parsed.add(k);
            }
            kinds = parsed;
          }
          SpecStateFilter? state;
          final stateName = _str(args, 'state');
          if (stateName != null) {
            state = SpecStateFilter.values
                .where((e) => e.name == stateName)
                .cast<SpecStateFilter?>()
                .firstWhere((_) => true, orElse: () => null);
            if (state == null) return _err('Unknown state "$stateName".');
          }
          final query = SpecQuery(
            text: _str(args, 'text'),
            regex: _flag(args, 'regex'),
            caseInsensitive: _flag(args, 'caseInsensitive'),
            kinds: kinds,
            className: _str(args, 'className'),
            sectionIdExact: _str(args, 'sectionIdExact'),
            sectionIdPrefix: _str(args, 'sectionIdPrefix'),
            pathGlob: _str(args, 'pathGlob'),
            mapsTo: _str(args, 'mapsTo'),
            detailedIn: _str(args, 'detailedIn'),
            state: state,
          );
          final page = docs.search(query, pageSize: _int(args, 'pageSize'));
          return _ok(page.toJson());
        },
      );

  SdkMcpTool _docSearchIterate() => SdkMcpTool(
        name: 'doc_search_iterate',
        description:
            'Advance an open doc_search cursor by one page (the §6 edit-stable '
            'lazy iteration). Rejects an unknown or exhausted cursor.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'cursorId': {'type': 'string'},
            'pageSize': {'type': 'integer'},
          },
          'required': ['cursorId'],
        },
        handler: (args) async {
          final docs = await _docs();
          final cursorId = _str(args, 'cursorId');
          if (cursorId == null) return _err('Missing "cursorId".');
          try {
            final page = docs.iterate(cursorId, pageSize: _int(args, 'pageSize'));
            return _ok(page.toJson());
          } on ArgumentError catch (e) {
            return _err(e.message?.toString() ?? 'invalid cursor');
          }
        },
      );

  SdkMcpTool _docReflect() => SdkMcpTool(
        name: 'doc_reflect',
        description:
            'The meta-model facts a node addresses: kind/class, @SectionId / '
            '@MapsTo / @DetailedIn, class annotations, and the model-permitted '
            'children (the segments doc_add_node accepts).',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Section-id path.'},
          },
          'required': ['path'],
        },
        handler: (args) async {
          final docs = await _docs();
          final path = _str(args, 'path');
          if (path == null) return _err('Missing "path".');
          return _ok(docs.reflect(path).toJson());
        },
      );

  SdkMcpTool _docAddNode() => SdkMcpTool(
        name: 'doc_add_node',
        description:
            'Meta-model-validated creation of a child segment under a parent '
            'path (mutation); lands in the one change log. A model violation is '
            'returned as a coded failed result, never thrown.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'parentPath': {'type': 'string'},
            'childSegment': {'type': 'string'},
            'itemId': {
              'type': 'string',
              'description': 'Explicit list-item id (optional).',
            },
          },
          'required': ['parentPath', 'childSegment'],
        },
        handler: (args) async {
          final docs = await _docs();
          final parentPath = _str(args, 'parentPath');
          final childSegment = _str(args, 'childSegment');
          if (parentPath == null || childSegment == null) {
            return _err('Missing "parentPath"/"childSegment".');
          }
          final result = docs.addNode(
            parentPath,
            childSegment,
            itemId: _str(args, 'itemId'),
          );
          return _ok(result.toJson());
        },
      );

  // --- file_* (audited read-any / write-whitelist) ------------------------

  SdkMcpTool _fileRead() => SdkMcpTool(
        name: 'file_read',
        description:
            'Read the full text of a file (read is permitted anywhere). '
            'Reports exists:false for a missing file rather than failing.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'path': {'type': 'string'},
          },
          'required': ['path'],
        },
        handler: (args) async {
          final path = _str(args, 'path');
          if (path == null) return _err('Missing "path".');
          return _ok(_fileTools.read(path).toJson());
        },
      );

  SdkMcpTool _fileFind() => SdkMcpTool(
        name: 'file_find',
        description:
            'List paths under a directory whose basename matches a glob '
            '(read-only exploration; dir defaults to the workspace root).',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'glob': {'type': 'string'},
            'dir': {'type': 'string'},
          },
          'required': ['glob'],
        },
        handler: (args) async {
          final glob = _str(args, 'glob');
          if (glob == null) return _err('Missing "glob".');
          return _ok(_fileTools.find(glob, dir: _str(args, 'dir') ?? '.').toJson());
        },
      );

  SdkMcpTool _fileWrite() => SdkMcpTool(
        name: 'file_write',
        description:
            'Write content to a path (whitelist-checked). A path outside the '
            'writable whitelist returns a failed result; nothing is written.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'path': {'type': 'string'},
            'content': {'type': 'string'},
          },
          'required': ['path', 'content'],
        },
        handler: (args) async {
          final path = _str(args, 'path');
          final content = _str(args, 'content');
          if (path == null || content == null) {
            return _err('Missing "path"/"content".');
          }
          return _ok(_fileTools.write(path, content).toJson());
        },
      );

  // --- script_* (author / validate / run / list / get) -------------------

  SdkMcpTool _scriptAuthor() => SdkMcpTool(
        name: 'script_author',
        description:
            'Store a named D4rt script under agent/scripts/, recording the '
            'scopes it targets. Throws on an unsafe name.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'source': {'type': 'string'},
            'scopes': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Defaults to ["spec"].',
            },
          },
          'required': ['name', 'source'],
        },
        handler: (args) async {
          final name = _str(args, 'name');
          final source = _str(args, 'source');
          if (name == null || source == null) {
            return _err('Missing "name"/"source".');
          }
          try {
            final authored = scriptTools.author(
              name,
              source,
              scopes: _strList(args, 'scopes') ?? const ['spec'],
            );
            return _ok(authored.toJson());
          } on ArgumentError catch (e) {
            return _err(e.message?.toString() ?? 'invalid script');
          }
        },
      );

  SdkMcpTool _scriptValidate() => SdkMcpTool(
        name: 'script_validate',
        description:
            'Parse / declaration-resolve a script (raw source or a stored name) '
            'against the granted scope WITHOUT running it; returns diagnostics.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'source': {'type': 'string'},
            'name': {'type': 'string', 'description': 'A stored script name.'},
            'scopes': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        },
        handler: (args) async {
          try {
            final validation = scriptTools.validate(
              source: _str(args, 'source'),
              name: _str(args, 'name'),
              scopes: _strList(args, 'scopes'),
            );
            return _ok(validation.toJson());
          } on ArgumentError catch (e) {
            return _err(e.message?.toString() ?? 'invalid request');
          }
        },
      );

  SdkMcpTool _scriptRun() => SdkMcpTool(
        name: 'script_run',
        description:
            'Run a script (raw source or a stored name) under the named scopes, '
            'capturing stdout, the auto-awaited main() return, and any error + '
            'stack. Mutations land in the one change log.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'source': {'type': 'string'},
            'name': {'type': 'string', 'description': 'A stored script name.'},
            'scopes': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        },
        handler: (args) async {
          try {
            final result = await scriptTools.run(
              source: _str(args, 'source'),
              name: _str(args, 'name'),
              scopes: _strList(args, 'scopes'),
            );
            return _ok(result.toJson());
          } on ArgumentError catch (e) {
            return _err(e.message?.toString() ?? 'invalid request');
          }
        },
      );

  SdkMcpTool _scriptList() => SdkMcpTool(
        name: 'script_list',
        description: 'Every stored script, with its recorded scopes and source.',
        inputSchema: const {'type': 'object', 'properties': {}},
        handler: (args) async =>
            _ok({'scripts': [for (final s in scriptTools.list()) s.toJson()]}),
      );

  SdkMcpTool _scriptGet() => SdkMcpTool(
        name: 'script_get',
        description: 'The stored script of the given name (header + source).',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
          'required': ['name'],
        },
        handler: (args) async {
          final name = _str(args, 'name');
          if (name == null) return _err('Missing "name".');
          try {
            return _ok(scriptTools.get(name).toJson());
          } on ArgumentError catch (e) {
            return _err(e.message?.toString() ?? 'no such script');
          }
        },
      );
}
