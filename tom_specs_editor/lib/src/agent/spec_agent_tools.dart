import 'dart:convert';

import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import '../document/spec_document_controller.dart';
import '../structure/review_store.dart';
import '../structure/spec_model.dart';

/// Builds the in-process MCP server exposing the
/// `tom_specs_editor_specification.md` §8 navigation & mutation tools.
///
/// The three layers (A = object-model schema, B = live instance structure, C =
/// live content) plus the five mutations are all routed through one shared
/// [SpecDocumentController], so the agent and the UI act on the same document.
/// Every handler returns **compact JSON** (`jsonEncode`, no pretty-printing) as
/// a single text content item; failures set `isError` and carry `{"error": …}`.
class SpecAgentTools {
  SpecAgentTools(this.controller);

  /// The shared document controller every tool reads/mutates through.
  final SpecDocumentController controller;

  /// Assembles the `McpSdkServerConfig` registered into `Options.mcpServers`.
  McpSdkServerConfig buildServer({String name = 'tomspecs'}) =>
      McpSdkServerConfig(
        name: name,
        tools: [
          _modelListDocuments(),
          _modelGetSection(),
          _modelChildren(),
          _modelSearch(),
          _docOutline(),
          _docSectionMeta(),
          _docGetContent(),
          _docGetFormField(),
          _docSetContent(),
          _docSetFormField(),
          _docAddListItem(),
          _docRemoveListItem(),
          _docSetReview(),
        ],
      );

  // --- result helpers --------------------------------------------------------

  CallToolResult _ok(Object? payload) =>
      CallToolResult.text(jsonEncode(payload));

  CallToolResult _err(String message) =>
      CallToolResult.text(jsonEncode({'error': message}), isError: true);

  String? _str(Map<String, dynamic> args, String key) => args[key]?.toString();

  bool? _bool(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return null;
  }

  Map<String, Object?> _fieldSummary(SpecField f) => {
    'name': f.name,
    'kind': f.kind.name,
    if (f.sectionId != null) 'sectionId': f.sectionId,
    if (f.type != null) 'type': f.type,
    if (f.elementType != null) 'elementType': f.elementType,
  };

  Map<String, Object?> _classSummary(SpecClass c) => {
    'name': c.name,
    if (c.sectionId != null) 'sectionId': c.sectionId,
    if (c.doc != null) 'doc': c.doc,
    'fields': [for (final f in c.fields) _fieldSummary(f)],
  };

  // --- Layer A ---------------------------------------------------------------

  SdkMcpTool _modelListDocuments() => SdkMcpTool(
    name: 'model_list_documents',
    description:
        'List the TomSpecs document roots (Layer A schema): id, type, '
        'title, section id.',
    inputSchema: const {'type': 'object', 'properties': {}},
    handler: (args) async {
      await controller.ensureLoaded();
      return _ok({
        'documents': [
          for (final r in controller.model.roots)
            {
              'id': r.sectionId ?? r.type,
              'type': r.type,
              'title': r.title,
              if (r.sectionId != null) 'sectionId': r.sectionId,
            },
        ],
      });
    },
  );

  SdkMcpTool _modelGetSection() => SdkMcpTool(
    name: 'model_get_section',
    description:
        'Get the schema of a class/section by class name or section id '
        '(Layer A): its fields, kinds and types.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Class name or section id.'},
      },
      'required': ['id'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final id = _str(args, 'id');
      if (id == null) return _err('Missing "id".');
      final c = controller.classById(id);
      if (c == null) return _err('No class/section "$id".');
      return _ok(_classSummary(c));
    },
  );

  SdkMcpTool _modelChildren() => SdkMcpTool(
    name: 'model_children',
    description:
        'List the immediate child fields of a class/section (Layer A).',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Class name or section id.'},
      },
      'required': ['id'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final id = _str(args, 'id');
      if (id == null) return _err('Missing "id".');
      final c = controller.classById(id);
      if (c == null) return _err('No class/section "$id".');
      return _ok({
        'id': c.sectionId ?? c.name,
        'children': [for (final f in c.fields) _fieldSummary(f)],
      });
    },
  );

  SdkMcpTool _modelSearch() => SdkMcpTool(
    name: 'model_search',
    description:
        'Search the object model for classes/fields whose name, section id '
        'or doc contains the query (Layer A); capped at 50 hits.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
      },
      'required': ['query'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final query = _str(args, 'query')?.toLowerCase();
      if (query == null || query.isEmpty) return _err('Missing "query".');
      final hits = <Map<String, Object?>>[];
      for (final c in controller.model.classes.values) {
        if (hits.length >= 50) break;
        final inClass =
            c.name.toLowerCase().contains(query) ||
            (c.sectionId?.toLowerCase().contains(query) ?? false) ||
            (c.doc?.toLowerCase().contains(query) ?? false);
        if (inClass) {
          hits.add({
            'class': c.name,
            if (c.sectionId != null) 'sectionId': c.sectionId,
          });
          continue;
        }
        for (final f in c.fields) {
          if (hits.length >= 50) break;
          if (f.name.toLowerCase().contains(query) ||
              (f.sectionId?.toLowerCase().contains(query) ?? false)) {
            hits.add({
              'class': c.name,
              'field': f.name,
              if (f.sectionId != null) 'sectionId': f.sectionId,
            });
            continue;
          }
          for (final ff in f.formFields) {
            if (hits.length >= 50) break;
            if (ff.name.toLowerCase().contains(query) ||
                ff.label.toLowerCase().contains(query)) {
              hits.add({
                'class': c.name,
                'field': f.name,
                'formField': ff.name,
              });
            }
          }
        }
      }
      return _ok({'hits': hits, 'truncated': hits.length >= 50});
    },
  );

  // --- Layer B ---------------------------------------------------------------

  SdkMcpTool _docOutline() => SdkMcpTool(
    name: 'doc_outline',
    description:
        'Outline the live document structure under a root (Layer B): ids, '
        'kinds, list counts and items, no content body.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'rootId': {
          'type': 'string',
          'description': 'Root section id/type; defaults to the first root.',
        },
        'depth': {'type': 'integer'},
      },
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final roots = controller.model.roots;
      if (roots.isEmpty) return _err('No document roots.');
      final rootId =
          _str(args, 'rootId') ?? (roots.first.sectionId ?? roots.first.type);
      final depthRaw = args['depth'];
      final depth = depthRaw is int
          ? depthRaw
          : (depthRaw is String ? int.tryParse(depthRaw) : null);
      final result = controller.outline(rootId, depth: depth);
      if (result == null) return _err('No root "$rootId".');
      return _ok(result);
    },
  );

  SdkMcpTool _docSectionMeta() => SdkMcpTool(
    name: 'doc_section_meta',
    description:
        'Identity/cardinality of one live section by section-id path '
        '(Layer B): kind, type, list count, form fields — no body.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Section-id path.'},
      },
      'required': ['id'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final id = _str(args, 'id');
      if (id == null) return _err('Missing "id".');
      final meta = controller.sectionMeta(id);
      if (meta == null) return _err('No section "$id".');
      return _ok(meta);
    },
  );

  // --- Layer C ---------------------------------------------------------------

  SdkMcpTool _docGetContent() => SdkMcpTool(
    name: 'doc_get_content',
    description: 'Read the content string of a section (Layer C).',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Section-id path.'},
      },
      'required': ['id'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final id = _str(args, 'id');
      if (id == null) return _err('Missing "id".');
      return _ok({'id': id, 'value': controller.content(id)});
    },
  );

  SdkMcpTool _docGetFormField() => SdkMcpTool(
    name: 'doc_get_form_field',
    description: 'Read one form field of a @Form section (Layer C).',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Section-id path.'},
        'field': {'type': 'string'},
      },
      'required': ['id', 'field'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final id = _str(args, 'id');
      final field = _str(args, 'field');
      if (id == null || field == null) {
        return _err('Missing "id"/"field".');
      }
      return _ok({
        'id': id,
        'field': field,
        'value': controller.formField(id, field),
      });
    },
  );

  // --- Mutations -------------------------------------------------------------

  SdkMcpTool _docSetContent() => SdkMcpTool(
    name: 'doc_set_content',
    description:
        'Set the content string of a section (mutation); edits the live '
        'document.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Section-id path.'},
        'value': {'type': 'string'},
      },
      'required': ['id', 'value'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final id = _str(args, 'id');
      final value = _str(args, 'value');
      if (id == null || value == null) {
        return _err('Missing "id"/"value".');
      }
      controller.setContent(id, value);
      return _ok({'id': id, 'value': value, 'ok': true});
    },
  );

  SdkMcpTool _docSetFormField() => SdkMcpTool(
    name: 'doc_set_form_field',
    description:
        'Set one form field of a @Form section (mutation); edits the live '
        'document.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Section-id path.'},
        'field': {'type': 'string'},
        'value': {'type': 'string'},
      },
      'required': ['id', 'field', 'value'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final id = _str(args, 'id');
      final field = _str(args, 'field');
      final value = _str(args, 'value');
      if (id == null || field == null || value == null) {
        return _err('Missing "id"/"field"/"value".');
      }
      controller.setFormField(id, field, value);
      return _ok({'id': id, 'field': field, 'value': value, 'ok': true});
    },
  );

  SdkMcpTool _docAddListItem() => SdkMcpTool(
    name: 'doc_add_list_item',
    description:
        'Append an item to a list section (mutation); returns the new '
        'item path.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'listId': {'type': 'string', 'description': 'List section-id path.'},
      },
      'required': ['listId'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final listId = _str(args, 'listId');
      if (listId == null) return _err('Missing "listId".');
      final itemPath = controller.addListItem(listId);
      return _ok({
        'listId': listId,
        'itemId': itemPath,
        'count': controller.document.listItems(listId).length,
      });
    },
  );

  SdkMcpTool _docRemoveListItem() => SdkMcpTool(
    name: 'doc_remove_list_item',
    description:
        'Remove a list item by its item path (mutation); also drops its '
        'nested values.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'List item path (…-N).'},
      },
      'required': ['id'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final id = _str(args, 'id');
      if (id == null) return _err('Missing "id".');
      final removed = controller.removeListItem(id);
      if (!removed) return _err('No list item "$id".');
      return _ok({'id': id, 'removed': true});
    },
  );

  SdkMcpTool _docSetReview() => SdkMcpTool(
    name: 'doc_set_review',
    description:
        'Record a structural-review decision on a node path (mutation); '
        'routes through the shared review store.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'path': {'type': 'string'},
        'scope': {
          'type': 'string',
          'description':
              'none | only_this_document | global | '
              'global_with_adaptations. (Legacy "only_pd" is also accepted '
              'on read for back-compat.)',
        },
        'stopHere': {'type': 'boolean'},
        'addDetails': {'type': 'boolean'},
        'mustBeList': {'type': 'boolean'},
        'singleEntry': {'type': 'boolean'},
        'mustBeContentString': {'type': 'boolean'},
        'convertFormToContent': {'type': 'boolean'},
        'reviewed': {'type': 'boolean'},
        'comment': {'type': 'string'},
      },
      'required': ['path'],
    },
    handler: (args) async {
      await controller.ensureLoaded();
      final path = _str(args, 'path');
      if (path == null) return _err('Missing "path".');
      controller.setReview(path, (e) {
        final scope = _str(args, 'scope');
        if (scope != null) e.scope = ReviewScope.parse(scope);
        final stopHere = _bool(args, 'stopHere');
        if (stopHere != null) e.stopHere = stopHere;
        final addDetails = _bool(args, 'addDetails');
        if (addDetails != null) e.addDetails = addDetails;
        final mustBeList = _bool(args, 'mustBeList');
        if (mustBeList != null) e.mustBeList = mustBeList;
        final singleEntry = _bool(args, 'singleEntry');
        if (singleEntry != null) e.singleEntry = singleEntry;
        final mustBeContentString = _bool(args, 'mustBeContentString');
        if (mustBeContentString != null) {
          e.mustBeContentString = mustBeContentString;
        }
        final convertFormToContent = _bool(args, 'convertFormToContent');
        if (convertFormToContent != null) {
          e.convertFormToContent = convertFormToContent;
        }
        final reviewed = _bool(args, 'reviewed');
        if (reviewed != null) e.reviewed = reviewed;
        final comment = _str(args, 'comment');
        if (comment != null) e.comment = comment;
      });
      final entry = controller.review.entryFor(path);
      return _ok({'path': path, 'ok': true, 'entry': entry?.toMap()});
    },
  );
}
