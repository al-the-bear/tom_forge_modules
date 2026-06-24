// Tests for the engine toolsets registered as MCP tools behind AgentToolsModule
// (followup item 5): DocTools (doc_*), FileTools (file_*), and ScriptTools
// (script_*) wrapped as `SdkMcpTool`s on the `tomspecs-engine` server.
//
// The item's Done condition: the four engine tool classes are reachable as MCP
// tools in the editor, each returning compact JSON, with mutations landing on
// the one shared controller (so a doc_add_node / script_run edit is coherent
// with the §8 tools). MemoryTools (mem_*) are intentionally absent — they need
// the server-only memory plane (item 6). These tests drive the handlers
// directly (no bridge transport).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import 'package:tom_specs_editor/src/agent/agent_tools_module.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A class graph with a content section, a form, and a list of complex items —
/// enough to exercise doc_search / doc_reflect / doc_add_node.
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
            {'name': 'summary', 'kind': 'content', 'sectionId': 'D00-SUM'},
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
    scriptWorkspaceRoot: dir.path,
  );
  final server = module.servers['tomspecs-engine'] as McpSdkServerConfig;
  final tools = {for (final t in server.tools) t.name: t};
  return (module: module, tools: tools, controller: module.controller);
}

/// Invokes a tool handler and returns its single decoded JSON payload, asserting
/// the compact-JSON contract.
Future<Map<String, dynamic>> _invoke(
  SdkMcpTool tool,
  Map<String, dynamic> args,
) async {
  final result = await tool.handler!(args);
  expect(result.content, hasLength(1));
  final item = result.content.single;
  expect(item['type'], 'text');
  final text = item['text'] as String;
  expect(text.contains('\n'), isFalse, reason: 'must be compact JSON');
  return jsonDecode(text) as Map<String, dynamic>;
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('specs_engine_tools_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the engine server registers the doc_/file_/script_/mem_ tools', () {
    final h = _harness(dir);
    expect(
      h.tools.keys.toSet(),
      {
        'doc_search',
        'doc_search_iterate',
        'doc_reflect',
        'doc_add_node',
        'file_read',
        'file_find',
        'file_write',
        'script_author',
        'script_validate',
        'script_run',
        'script_list',
        'script_get',
        // The embeddable memory plane (followup item 6) is now linked in-editor.
        'mem_recall',
        'mem_refresh',
      },
    );
  });

  group('doc_* tools', () {
    test('doc_reflect on the root exposes the model-permitted children',
        () async {
      final h = _harness(dir);
      final r = await _invoke(h.tools['doc_reflect']!, {'path': 'D00'});
      expect(r['resolved'], isTrue);
      expect(r['classId'], 'DemoDoc');
      final children = (r['allowedChildren'] as List).cast<Map>();
      final segments = [for (final c in children) c['segment']];
      expect(segments, contains('D00-ITM'));
    });

    test('doc_reflect on an unknown path reports unresolved', () async {
      final h = _harness(dir);
      final r = await _invoke(h.tools['doc_reflect']!, {'path': 'NOPE'});
      expect(r['resolved'], isFalse);
    });

    test('doc_add_node appends a list item; it lands on the shared controller',
        () async {
      final h = _harness(dir);
      final r = await _invoke(
        h.tools['doc_add_node']!,
        {'parentPath': 'D00', 'childSegment': 'D00-ITM'},
      );
      expect(r['ok'], isTrue);
      expect(r['path'], 'D00/D00-ITM-1');
      // The mutation is visible on the one shared document.
      expect(h.controller.document.listItems('D00/D00-ITM'),
          ['D00/D00-ITM-1']);
      expect(h.controller.changeLog.length, 1);
    });

    test('doc_add_node returns a coded failure for an illegal segment',
        () async {
      final h = _harness(dir);
      final r = await _invoke(
        h.tools['doc_add_node']!,
        {'parentPath': 'D00', 'childSegment': 'NOPE'},
      );
      expect(r['ok'], isFalse);
      expect(r['code'], isNotNull);
    });

    test('doc_search finds a content node and the cursor iterates', () async {
      final h = _harness(dir);
      // Seed two content values to search. The query engine indexes by the full
      // structural path (root segment + field segment), so the content nodes
      // live at 'D00/D00-OVR' and 'D00/D00-SUM', not the bare section ids. Two
      // matches mean a page size of 1 leaves the cursor live after the first
      // page, so the cursor genuinely round-trips through doc_search_iterate.
      h.controller.setContent('D00/D00-OVR', 'find the needle here');
      h.controller.setContent('D00/D00-SUM', 'another needle nearby');
      final first = await _invoke(
        h.tools['doc_search']!,
        {'text': 'needle', 'pageSize': 1},
      );
      final matches = (first['matches'] as List).cast<Map>();
      expect(matches, hasLength(1));
      expect(matches.first['snippet'], contains('needle'));
      expect(first['done'], isFalse);
      // The cursor id round-trips through doc_search_iterate to the next page.
      final cursorId = first['cursorId'] as String;
      final next = await _invoke(
        h.tools['doc_search_iterate']!,
        {'cursorId': cursorId},
      );
      expect(next.containsKey('done'), isTrue);
      expect(next['done'], isTrue);
    });

    test('doc_search_iterate rejects an unknown cursor', () async {
      final h = _harness(dir);
      final result =
          await h.tools['doc_search_iterate']!.handler!({'cursorId': 'bogus'});
      expect(result.isError, isTrue);
    });
  });

  group('file_* tools', () {
    test('file_write into the scratchpad whitelist, then file_read it back',
        () async {
      final h = _harness(dir);
      final w = await _invoke(
        h.tools['file_write']!,
        {'path': 'agent/scratchpad/note.txt', 'content': 'hello engine'},
      );
      expect(w['ok'], isTrue);
      final r = await _invoke(
        h.tools['file_read']!,
        {'path': 'agent/scratchpad/note.txt'},
      );
      expect(r['exists'], isTrue);
      expect(r['content'], 'hello engine');
    });

    test('file_write outside the whitelist is a coded failure, not a throw',
        () async {
      final h = _harness(dir);
      final w = await _invoke(
        h.tools['file_write']!,
        {'path': 'forbidden.txt', 'content': 'nope'},
      );
      expect(w['ok'], isFalse);
      expect(w['error'], isNotNull);
      expect(File('${dir.path}/forbidden.txt').existsSync(), isFalse);
    });

    test('file_find matches by basename glob', () async {
      final h = _harness(dir);
      await _invoke(
        h.tools['file_write']!,
        {'path': 'agent/scratchpad/found.md', 'content': '# x'},
      );
      final f = await _invoke(
        h.tools['file_find']!,
        {'glob': '*.md', 'dir': 'agent/scratchpad'},
      );
      final matches = (f['matches'] as List).cast<String>();
      expect(matches.any((m) => m.endsWith('found.md')), isTrue);
    });

    test('file_read of a missing file reports exists:false', () async {
      final h = _harness(dir);
      final r = await _invoke(h.tools['file_read']!, {'path': 'absent.txt'});
      expect(r['exists'], isFalse);
    });
  });

  group('script_* tools', () {
    test('script_run executes and captures stdout + the main() result',
        () async {
      final h = _harness(dir);
      final r = await _invoke(
        h.tools['script_run']!,
        {'source': "main() { print('hi'); return 21 * 2; }"},
      );
      expect(r['ok'], isTrue);
      expect(r['stdout'], contains('hi'));
      expect(r['result'], 42);
    });

    test('a script_run mutation lands on the shared controller (one change log)',
        () async {
      final h = _harness(dir);
      final r = await _invoke(h.tools['script_run']!, {
        'source': "import 'package:tom_spec_engine/spec_api.dart';\n"
            "main() { spec.setContent('D00-OVR', 'from engine tool'); }",
      });
      expect(r['ok'], isTrue, reason: r['error']?.toString());
      expect(h.controller.content('D00-OVR'), 'from engine tool');
      expect(h.controller.changeLog.length, 1);
    });

    test('script_author then script_get round-trips; script_list sees it',
        () async {
      final h = _harness(dir);
      final authored = await _invoke(
        h.tools['script_author']!,
        {'name': 'greet', 'source': "main() => 'hi';"},
      );
      expect(authored['name'], 'greet');
      final got = await _invoke(h.tools['script_get']!, {'name': 'greet'});
      expect(got['source'], contains("main() => 'hi';"));
      final listed = await _invoke(h.tools['script_list']!, {});
      final names = [
        for (final s in (listed['scripts'] as List).cast<Map>()) s['name'],
      ];
      expect(names, contains('greet'));
    });

    test('script_validate accepts a well-formed script', () async {
      final h = _harness(dir);
      final v = await _invoke(
        h.tools['script_validate']!,
        {'source': 'main() => 1;'},
      );
      expect(v['ok'], isTrue);
    });

    test('script_author rejects an unsafe name with a coded error', () async {
      final h = _harness(dir);
      final result = await h.tools['script_author']!.handler!(
        {'name': '../escape', 'source': 'main(){}'},
      );
      expect(result.isError, isTrue);
    });
  });
}
