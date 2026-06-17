// Tests for the §8 navigation & mutation tools (step 14).
//
// The step's Done condition: each tool returns compact JSON, and a mutation
// tool edits the live model. These tests drive the `SdkMcpTool` handlers
// directly (the bridge transport is not involved) and assert the JSON shape
// plus the controller/document/review side-effects.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import 'package:tom_specs_editor/src/agent/agent_tools_module.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A minimal class graph covering the writable field kinds: a content section,
/// a form, and a list of complex items each carrying a content field.
Map<String, dynamic> _sampleJson() => {
      'roots': [
        {'type': 'DemoDoc', 'title': 'Demo Document', 'sectionId': 'D00'},
      ],
      'classes': {
        'DemoDoc': {
          'name': 'DemoDoc',
          'sectionId': 'D00',
          'doc': 'A demo document.',
          'fields': [
            {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
            {
              'name': 'header',
              'kind': 'form',
              'sectionId': 'D00-HDR',
              'formFields': [
                {'name': 'author', 'label': 'Author', 'type': 'String'},
                {'name': 'date', 'label': 'Date', 'type': 'String'},
              ],
            },
            {
              'name': 'items',
              'kind': 'list',
              'elementType': 'DemoItem',
              'elementIsComplex': true,
              'sectionId': 'D00-ITM',
            },
          ],
        },
        'DemoItem': {
          'name': 'DemoItem',
          'fields': [
            {'name': 'label', 'kind': 'content', 'sectionId': 'D01-LBL'},
          ],
        },
      },
    };

/// Builds an agent-tools module backed by the sample model and a temp-file
/// review store, returning the module plus the assembled `SdkMcpTool` map.
({
  AgentToolsModule module,
  Map<String, SdkMcpTool> tools,
  SpecDocumentController controller,
}) _harness(Directory dir) {
  final model = SpecModel.fromJson(_sampleJson());
  final review = ReviewStore(File('${dir.path}/review.yaml'));
  final module = AgentToolsModule(
    modelFuture: Future<SpecModel>.value(model),
    review: review,
  );
  final server = module.servers['tomspecs'] as McpSdkServerConfig;
  final tools = {for (final t in server.tools) t.name: t};
  return (module: module, tools: tools, controller: module.controller);
}

/// Invokes a tool handler and returns its single decoded JSON payload.
Future<Map<String, dynamic>> _invoke(
  SdkMcpTool tool,
  Map<String, dynamic> args,
) async {
  final result = await tool.handler!(args);
  // Exactly one compact-JSON text content item.
  expect(result.content, hasLength(1));
  final item = result.content.single;
  expect(item['type'], 'text');
  final text = item['text'] as String;
  // Compact = no pretty-print newlines/indentation.
  expect(text.contains('\n'), isFalse);
  return jsonDecode(text) as Map<String, dynamic>;
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('specs_agent_tools_');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('the server exposes all 13 §8 tools', () {
    final h = _harness(dir);
    expect(
      h.tools.keys,
      containsAll(<String>[
        'model_list_documents',
        'model_get_section',
        'model_children',
        'model_search',
        'doc_outline',
        'doc_section_meta',
        'doc_get_content',
        'doc_get_form_field',
        'doc_set_content',
        'doc_set_form_field',
        'doc_add_list_item',
        'doc_remove_list_item',
        'doc_set_review',
      ]),
    );
  });

  group('Layer A — schema', () {
    test('model_list_documents returns the roots as compact JSON', () async {
      final h = _harness(dir);
      final json = await _invoke(h.tools['model_list_documents']!, {});
      final docs = json['documents'] as List;
      expect(docs, hasLength(1));
      expect((docs.single as Map)['type'], 'DemoDoc');
      expect((docs.single as Map)['id'], 'D00');
    });

    test('model_get_section resolves by section id and lists fields', () async {
      final h = _harness(dir);
      final json = await _invoke(h.tools['model_get_section']!, {'id': 'D00'});
      expect(json['name'], 'DemoDoc');
      final fields = (json['fields'] as List).cast<Map>();
      expect(fields.map((f) => f['name']),
          containsAll(['overview', 'header', 'items']));
    });

    test('model_search finds a field by name', () async {
      final h = _harness(dir);
      final json = await _invoke(h.tools['model_search']!, {'query': 'author'});
      final hits = (json['hits'] as List).cast<Map>();
      expect(hits.any((m) => m['formField'] == 'author'), isTrue);
    });

    test('unknown section id is a structured error', () async {
      final h = _harness(dir);
      final result =
          await h.tools['model_get_section']!.handler!({'id': 'nope'});
      expect(result.isError, isTrue);
      final json = jsonDecode(result.content.single['text'] as String);
      expect(json['error'], isNotNull);
    });
  });

  group('Mutations edit the live model', () {
    test('doc_set_content writes content visible to doc_get_content',
        () async {
      final h = _harness(dir);
      final set = await _invoke(
        h.tools['doc_set_content']!,
        {'id': 'D00/D00-OVR', 'value': 'Hello world'},
      );
      expect(set['ok'], isTrue);
      // The live document holds the value.
      await h.controller.ensureLoaded();
      expect(h.controller.content('D00/D00-OVR'), 'Hello world');
      // And reading it back through the tool returns it.
      final got = await _invoke(
        h.tools['doc_get_content']!,
        {'id': 'D00/D00-OVR'},
      );
      expect(got['value'], 'Hello world');
    });

    test('doc_set_form_field writes one field of a form', () async {
      final h = _harness(dir);
      await _invoke(
        h.tools['doc_set_form_field']!,
        {'id': 'D00/D00-HDR', 'field': 'author', 'value': 'Ada'},
      );
      await h.controller.ensureLoaded();
      expect(h.controller.formField('D00/D00-HDR', 'author'), 'Ada');
      final got = await _invoke(
        h.tools['doc_get_form_field']!,
        {'id': 'D00/D00-HDR', 'field': 'author'},
      );
      expect(got['value'], 'Ada');
    });

    test('doc_add_list_item then doc_outline reflects the new count',
        () async {
      final h = _harness(dir);
      final added = await _invoke(
        h.tools['doc_add_list_item']!,
        {'listId': 'D00/D00-ITM'},
      );
      expect(added['count'], 1);
      final itemId = added['itemId'] as String;
      expect(itemId, 'D00/D00-ITM-1');

      // The outline reports the live count and the item path.
      final outline = await _invoke(h.tools['doc_outline']!, {});
      final children = (outline['children'] as List).cast<Map>();
      final itemsNode =
          children.firstWhere((c) => c['id'] == 'D00/D00-ITM');
      expect(itemsNode['count'], 1);
      final itemNodes = (itemsNode['items'] as List).cast<Map>();
      expect(itemNodes.single['id'], 'D00/D00-ITM-1');

      // Content set on the item is purged when the item is removed.
      await _invoke(
        h.tools['doc_set_content']!,
        {'id': 'D00/D00-ITM-1/D01-LBL', 'value': 'first'},
      );
      expect(h.controller.content('D00/D00-ITM-1/D01-LBL'), 'first');
      final removed = await _invoke(
        h.tools['doc_remove_list_item']!,
        {'id': 'D00/D00-ITM-1'},
      );
      expect(removed['removed'], isTrue);
      expect(h.controller.content('D00/D00-ITM-1/D01-LBL'), isNull);
      expect(h.controller.document.listItems('D00/D00-ITM'), isEmpty);
    });

    test('doc_section_meta reports list cardinality', () async {
      final h = _harness(dir);
      await _invoke(h.tools['doc_add_list_item']!, {'listId': 'D00/D00-ITM'});
      await _invoke(h.tools['doc_add_list_item']!, {'listId': 'D00/D00-ITM'});
      final meta = await _invoke(
        h.tools['doc_section_meta']!,
        {'id': 'D00/D00-ITM'},
      );
      expect(meta['kind'], 'list');
      expect(meta['count'], 2);
      expect(meta['elementType'], 'DemoItem');
    });
  });

  group('doc_set_review routes to the shared ReviewStore', () {
    test('records a decision persisted by the store', () async {
      final h = _harness(dir);
      final json = await _invoke(
        h.tools['doc_set_review']!,
        {
          'path': 'D00/D00-ITM',
          'scope': 'global',
          'addDetails': true,
          'comment': 'shared across documents',
        },
      );
      expect(json['ok'], isTrue);
      final entry = h.controller.review.entryFor('D00/D00-ITM');
      expect(entry, isNotNull);
      expect(entry!.scope, ReviewScope.global);
      expect(entry.addDetails, isTrue);
      expect(entry.comment, 'shared across documents');
    });
  });
}
