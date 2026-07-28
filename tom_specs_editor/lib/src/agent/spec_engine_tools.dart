import 'dart:convert';

import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show SpecQuery, SpecQueryEngine;
import 'package:tom_spec_engine/memory.dart' show MemRecallMode, MemoryTools;
import 'package:tom_spec_engine/scripting.dart'
    show DocTools, FileTools, ScriptTools, SpecFileFacade, specQueryFromArgs;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import '../document/spec_document_controller.dart';
import 'engine_spec_controller.dart';

/// Builds the in-process MCP server exposing the **engine's**
/// llm_and_d4rt_tools.md §8.2 / §8.1 tool classes (plan step 5 of
/// `d4rt_and_llm_tools_followup.md`).
///
/// Where [SpecAgentTools] exposes the editor's bespoke layer-A/B/C navigation +
/// mutation tools, this server registers the reusable engine toolsets that live
/// in `tom_spec_engine` so the agent reaches the *same* surfaces a headless run
/// would:
///
///   * [DocTools] → `doc_search` / `doc_search_iterate` (the
///     `llm_and_d4rt_tools.md` §6 edit-stable cursor), `doc_reflect`
///     (meta-model facts), `doc_add_node` (a meta-model-validated add routed
///     through the one change log);
///   * [FileTools] → `file_read` / `file_find` / `file_write` over the audited
///     read-anywhere / write-whitelist [SpecFileFacade];
///   * [ScriptTools] → `script_author` / `script_validate` / `script_run` /
///     `script_list` / `script_get` over the shared `spec`-scope registry;
///   * [MemoryTools] → `mem_recall` / `mem_refresh` over the editor's embeddable
///     memory plane (followup item 6) — registered **only** when a [memoryTools]
///     is supplied, so a headless build with no memory plane still exposes the
///     `llm_and_d4rt_tools.md` §8.1/§8.2 surface unchanged.
///
/// Where a memory plane is wired, [ensureMemoryWarm] is awaited before each
/// memory-touching handler so the always-fresh tier-1 index is rebuilt and the
/// tier-2 store is opened before recall runs.
///
/// Every handler returns **compact JSON** (`jsonEncode`, no pretty-printing) as a
/// single text content item, mirroring [SpecAgentTools]; the engine result types
/// already carry a `toJson`. Failures set `isError` and carry `{"error": …}`.
class SpecEngineTools {
  /// Binds the toolsets to the shared [controller] (so `doc_add_node` and a
  /// `script_run` mutation land in the one change log), the audited file
  /// [facade], and the shared [scriptTools] (the same instance the editor's
  /// `SpecScriptRunner` drives, so authored scripts share one store).
  ///
  /// When [memoryTools] is supplied the `mem_*` tools are registered; the
  /// optional [ensureMemoryWarm] is awaited before each memory-touching handler.
  SpecEngineTools({
    required this.controller,
    required this.facade,
    required this.scriptTools,
    this.memoryTools,
    this.ensureMemoryWarm,
  });

  /// The shared document controller `doc_*` tools read/mutate through.
  final SpecDocumentController controller;

  /// The audited file surface the `file_*` tools operate over.
  final SpecFileFacade facade;

  /// The script toolset backing the `script_*` tools (shared with the runner).
  final ScriptTools scriptTools;

  /// The memory toolset backing the `mem_*` tools, or `null` to omit them.
  final MemoryTools? memoryTools;

  /// Awaited before each memory-touching handler to (re)warm the plane.
  final Future<void> Function()? ensureMemoryWarm;

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
          if (memoryTools != null) ...[_memRecall(), _memRefresh()],
        ],
      );

  // --- result helpers --------------------------------------------------------

  CallToolResult _ok(Object? payload) =>
      CallToolResult.text(jsonEncode(payload));

  CallToolResult _err(String message) =>
      CallToolResult.text(jsonEncode({'error': message}), isError: true);

  String? _str(Map<String, dynamic> args, String key) => args[key]?.toString();

  int? _int(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool _bool(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  List<String>? _strList(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is List) return [for (final e in v) e.toString()];
    if (v is String && v.isNotEmpty) {
      return [for (final e in v.split(',')) e.trim()];
    }
    return null;
  }

  Map<String, String>? _stringMap(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! Map) return null;
    return {
      for (final entry in v.entries)
        entry.key.toString(): entry.value?.toString() ?? '',
    };
  }

  /// Reads a JSON array as a list of positional arguments, preserving each
  /// element's JSON type (string / number / bool / null) so it reaches `main()`
  /// untouched. Returns `null` when the key is absent (no args supplied).
  List<Object?>? _jsonList(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! List) return null;
    return List<Object?>.from(v);
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

  // --- doc_* (`llm_and_d4rt_tools.md` §6 query + reflection + add) -------

  SdkMcpTool _docSearch() => SdkMcpTool(
        name: 'doc_search',
        description:
            'Run a llm_and_d4rt_tools.md §6 query over the live document and '
            'return the first page '
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
          // Build the `llm_and_d4rt_tools.md` §6 query through the *shared*
          // builder behind the in-script `search` facade (followup item 12), so
          // the tool and a script accept the same dimensions and coerce them
          // identically. Its ArgumentError (unknown kind / state) carries the
          // same message the inline parse used to emit.
          final SpecQuery query;
          try {
            query = specQueryFromArgs(args);
          } on ArgumentError catch (e) {
            return _err(e.message?.toString() ?? 'invalid query');
          }
          final page = docs.search(query, pageSize: _int(args, 'pageSize'));
          return _ok(page.toJson());
        },
      );

  SdkMcpTool _docSearchIterate() => SdkMcpTool(
        name: 'doc_search_iterate',
        description:
            'Advance an open doc_search cursor by one page (the '
            'llm_and_d4rt_tools.md §6 edit-stable '
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
            'returned as a coded failed result, never thrown. An optional '
            'initial payload populates the new node in the same call: "content" '
            'for a leaf value, "fields" (an object of field->value) for a form '
            'section.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'parentPath': {'type': 'string'},
            'childSegment': {'type': 'string'},
            'itemId': {
              'type': 'string',
              'description': 'Explicit list-item id (optional).',
            },
            'content': {
              'type': 'string',
              'description':
                  'Initial content for a leaf node (optional). Ignored when '
                  'empty.',
            },
            'fields': {
              'type': 'object',
              'additionalProperties': {'type': 'string'},
              'description':
                  'Initial form-field values for a form section (optional), '
                  'as field-name -> value.',
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
            content: _str(args, 'content'),
            fields: _stringMap(args, 'fields'),
          );
          return _ok(result.toJson());
        },
      );

  // --- file_* (audited read-any / write-whitelist) ---------------------------

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
            'List paths under a directory matching a glob (read-only '
            'exploration; dir defaults to the workspace root). The glob supports '
            '* / ** / ? / [...] / {a,b}; a glob containing "/" matches the path '
            'relative to the search root, otherwise the basename. With '
            'includeAssets the search also walks the profile-declared asset '
            'directories.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'glob': {'type': 'string'},
            'dir': {'type': 'string'},
            'includeAssets': {
              'type': 'boolean',
              'description':
                  'Also search the declared asset directories (default false).',
            },
          },
          'required': ['glob'],
        },
        handler: (args) async {
          final glob = _str(args, 'glob');
          if (glob == null) return _err('Missing "glob".');
          return _ok(_fileTools
              .find(
                glob,
                dir: _str(args, 'dir') ?? '.',
                includeAssets: _bool(args, 'includeAssets'),
              )
              .toJson());
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

  // --- script_* (author / validate / run / list / get) -----------------------

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
            'against the granted scope WITHOUT running it. Also type-checks the '
            'entrypoint: confirms a main() is declared and returns its argument '
            'contract (required/total positional params, named params, async). '
            'When "args" is given, checks them against that contract too. '
            'Returns {ok, diagnostics, entrypoint}.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'source': {'type': 'string'},
            'name': {'type': 'string', 'description': 'A stored script name.'},
            'scopes': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'args': {
              'type': 'array',
              'description': 'Optional positional args to check against main().',
            },
          },
        },
        handler: (args) async {
          try {
            final validation = scriptTools.validate(
              source: _str(args, 'source'),
              name: _str(args, 'name'),
              scopes: _strList(args, 'scopes'),
              args: _jsonList(args, 'args'),
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
            'stack. Pass "args" to forward positional arguments to main(); an '
            'arg-contract mismatch fails fast as an error result. Mutations land '
            'in the one change log.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'source': {'type': 'string'},
            'name': {'type': 'string', 'description': 'A stored script name.'},
            'scopes': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'args': {
              'type': 'array',
              'description': 'Optional positional args forwarded to main().',
            },
          },
        },
        handler: (args) async {
          try {
            final result = await scriptTools.run(
              source: _str(args, 'source'),
              name: _str(args, 'name'),
              scopes: _strList(args, 'scopes'),
              args: _jsonList(args, 'args'),
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

  // --- mem_* (the `llm_and_d4rt_tools.md` §9 fused two-tier recall) ----------

  SdkMcpTool _memRecall() => SdkMcpTool(
        name: 'mem_recall',
        description:
            'Recall the sections most relevant to a query from the live '
            'llm_and_d4rt_tools.md §9 '
            'two-tier memory (tier-1 lexical/structural fused with tier-2 '
            'vectors). Reports degraded:true when the vector tier is cold.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
            'mode': {
              'type': 'string',
              'description':
                  'Restrict hits to one mode: fused|lexical|symbolic|vector '
                  '(default fused).',
            },
            'k': {'type': 'integer', 'description': 'Max hits (default 10).'},
          },
          'required': ['query'],
        },
        handler: (args) async {
          final tools = memoryTools;
          if (tools == null) return _err('memory plane not wired');
          final query = _str(args, 'query');
          if (query == null) return _err('Missing "query".');
          final modeName = _str(args, 'mode');
          final MemRecallMode mode;
          if (modeName == null) {
            mode = MemRecallMode.fused;
          } else {
            final parsed = MemRecallMode.values
                .where((e) => e.name == modeName)
                .cast<MemRecallMode?>()
                .firstWhere((_) => true, orElse: () => null);
            if (parsed == null) return _err('Unknown mode "$modeName".');
            mode = parsed;
          }
          await ensureMemoryWarm?.call();
          final result = await tools.recallQuery(
            query,
            mode: mode,
            k: _int(args, 'k') ?? 10,
          );
          return _ok(result.toJson());
        },
      );

  SdkMcpTool _memRefresh() => SdkMcpTool(
        name: 'mem_refresh',
        description:
            'Re-index the live document into the memory plane: rebuild tier-1 '
            'and re-embed only the sections whose content moved (the '
            'embed-changed-only path). Reports refreshed:false in degraded mode.',
        inputSchema: const {'type': 'object', 'properties': {}},
        handler: (args) async {
          final tools = memoryTools;
          if (tools == null) return _err('memory plane not wired');
          await ensureMemoryWarm?.call();
          return _ok((await tools.refresh()).toJson());
        },
      );
}
