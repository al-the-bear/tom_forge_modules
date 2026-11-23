import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_editors_shared/text_types.dart' show ForgeTextSettings;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeSearchConfig;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'support/legacy_workspace_state_manager.dart';
import 'support/throwing_preferences_store.dart';

/// Every file under `.forge/` of [fs], by path, with revision ids (times)
/// replaced by their order — `r0`, `r1`, ... — so two runs compare.
Future<Map<String, String>> _forgeFiles(TomFileSystem fs) async {
  final files = <String, String>{};
  final store = ForgeFileStateStore(fs);
  for (final key in await store.keys()) {
    files[key] = await fs.readText(store.uriOf(key));
  }
  final ids = <String>[];
  for (final entry in files.entries) {
    if (entry.key.endsWith('/manifest.json')) {
      ids.addAll((jsonDecode(entry.value) as List).cast<String>());
    }
  }
  String normalize(String text) {
    for (var i = 0; i < ids.length; i++) {
      text = text.replaceAll(ids[i], 'r$i');
    }
    return text;
  }

  return {
    for (final entry in files.entries)
      normalize(entry.key): normalize(entry.value),
  };
}

/// The same operations on [manager]: every kind of document it keeps.
Future<void> _exercise(ForgeWorkspaceStateManager manager) async {
  final a = Uri.file('/ws/lib/a.dart');
  final b = Uri.file('/ws/README.md');
  await manager.saveOpenApplications(<String, Object?>{
    'active': 'forge.editors',
    'open': ['forge.editors', 'forge.terminal'],
    'ratio': 0.25,
  });
  await manager.saveEditorState(a, <String, dynamic>{
    'cursor': {'line': 3, 'column': 14},
    'folded': <int>[],
    'zoom': 1.0,
    'note': 'ünïcode "quoted"\nline',
  });
  await manager.saveEditorState(b, <String, dynamic>{'cursor': 0});
  await manager.createRevision(a, 'first\n');
  await Future<void>.delayed(const Duration(milliseconds: 3));
  await manager.createRevision(a, 'second\r\nwith crlf');
  await Future<void>.delayed(const Duration(milliseconds: 3));
  // Identical to the last: skipped.
  await manager.createRevision(a, 'second\r\nwith crlf');
  await Future<void>.delayed(const Duration(milliseconds: 3));
  await manager.createRevision(b, '');
  await manager.saveUndoHistory(a, [
    <String, dynamic>{'kind': 'insert', 'at': 4, 'text': 'x'},
    <String, dynamic>{'kind': 'delete', 'at': 2, 'length': 1},
  ]);
  await manager.saveConfig(<String, dynamic>{
    'editor': {'tabSize': 2},
    'empty': <String, dynamic>{},
  });
  await manager.saveApplicationState('forge.editors', <String, dynamic>{
    'layout': [1, 2, 3],
  });
  await manager.saveApplicationState('gone', <String, dynamic>{'x': true});
  await manager.deleteApplicationState('gone');
  await manager.flushed();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForgeMemoryStateStore', () {
    test('reads, writes, removes and lists keyed documents', () async {
      final store = ForgeMemoryStateStore(initial: {'a/1': 'one'});
      expect(await store.read('a/1'), 'one');
      await store.write('a/2', <String, Object?>{
        'n': 1,
        'd': 2.5,
        'l': [true, null],
      });
      await store.write('b', 3);
      expect(await store.keys(), ['a/1', 'a/2', 'b']);
      expect(await store.keys(prefix: 'a/'), ['a/1', 'a/2']);
      expect(await store.read('a/2'), {
        'n': 1,
        'd': 2.5,
        'l': [true, null],
      });
      await store.write('a/1', null);
      expect(await store.read('a/1'), isNull);
      expect(store.snapshot().keys, ['a/2', 'b']);
      await store.flushed();
    });

    test('copies documents in and out', () async {
      final store = ForgeMemoryStateStore();
      final document = <String, dynamic>{
        'list': [1],
      };
      await store.write('k', document);
      (document['list'] as List).add(2);
      final read = await store.read('k') as Map<String, dynamic>;
      expect(read, {
        'list': [1],
      });
      (read['list'] as List).add(3);
      expect(await store.read('k'), {
        'list': [1],
      });
      expect(read, isA<Map<String, dynamic>>());
      expect(
        () => store.write('bad', <String, Object?>{'x': Object()}),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
  });

  group('ForgeSharedPreferencesStateStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('stores each value type as shared_preferences did', () async {
      final store = ForgeSharedPreferencesStateStore();
      await store.write('forge.b', true);
      await store.write('forge.i', 42);
      await store.write('forge.d', 14.0);
      await store.write('forge.s', 'text');
      await store.write('forge.sl', <String>['x', 'y']);
      await store.write('forge.m', <String, Object?>{'a': 1});
      await store.write('forge.l', [1, 'two']);
      await store.write('other', 'x');
      await store.flushed();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('forge.b'), isTrue);
      expect(prefs.getInt('forge.i'), 42);
      expect(prefs.getDouble('forge.d'), 14.0);
      expect(prefs.get('forge.d'), isA<double>());
      expect(prefs.getString('forge.s'), 'text');
      expect(prefs.getStringList('forge.sl'), ['x', 'y']);
      expect(prefs.getString('forge.m'), '{"a":1}');
      expect(prefs.getString('forge.l'), '[1,"two"]');

      expect(await store.read('forge.i'), 42);
      expect(await store.read('forge.sl'), ['x', 'y']);
      expect(await store.read('forge.m'), '{"a":1}');
      expect(await store.keys(prefix: 'forge.'), [
        'forge.b',
        'forge.d',
        'forge.i',
        'forge.l',
        'forge.m',
        'forge.s',
        'forge.sl',
      ]);

      await store.write('forge.s', null);
      expect(prefs.containsKey('forge.s'), isFalse);
    });

    test('the kit preferences keep every key and encoding', () async {
      final preferences = ForgeKitPreferences();
      await preferences.load();
      preferences
        ..setEditorTextSettings(
          'md',
          const ForgeTextSettings(fontSize: 16, tabSize: 4),
        )
        ..setEditorSpecificConfig('md', <String, dynamic>{'preview': true})
        ..setFileTypeDefaultEditor('TXT', 'plain')
        ..setShortcutOverride(
          'a.find',
          const ForgeShortcutKey(
            key: LogicalKeyboardKey.keyF,
            primaryModifier: true,
          ),
        )
        ..setChordOverride(
          'a.fold',
          const ForgeChordKey(
            firstKey: ForgeShortcutKey(key: LogicalKeyboardKey.keyK),
            secondKey: ForgeShortcutKey(key: LogicalKeyboardKey.keyJ),
          ),
        )
        ..addDeletedBinding('a.gone')
        ..searchConfig = const ForgeSearchConfig(maxFileResults: 9);
      await preferences.setExternalToolPath('pandoc', '/bin/pandoc');
      await preferences.flushed();

      final prefs = await SharedPreferences.getInstance();
      final f = LogicalKeyboardKey.keyF.keyId;
      final k = LogicalKeyboardKey.keyK.keyId;
      final j = LogicalKeyboardKey.keyJ.keyId;
      final key =
          '"primaryModifier":false,"control":false,"shift":false,'
          '"alt":false';
      expect(prefs.getKeys(), {
        'forge.editor.textSettings',
        'forge.editor.specificConfig',
        'forge.files.typeDefaults',
        'forge.shortcuts.overrides',
        'forge.shortcuts.chordOverrides',
        'forge.shortcuts.deletedBindings',
        'forge.search.config',
        'forge.tools.pandoc.path',
      });
      expect(
        prefs.getString('forge.editor.textSettings'),
        jsonEncode({
          'md': {
            'fontFamily': const ForgeTextSettings().fontFamily,
            'uiFontFamily': null,
            'fontSize': 16.0,
            'lineHeight': const ForgeTextSettings().lineHeight,
            'tabSize': 4,
            'insertSpaces': true,
            'showWhitespace': false,
            'wordWrap': true,
            'showLineNumbers': true,
            'highlightCurrentLine': true,
            'maxUndoHistory': const ForgeTextSettings().maxUndoHistory,
          },
        }),
      );
      expect(
        prefs.getString('forge.editor.specificConfig'),
        '{"md":{"preview":true}}',
      );
      expect(prefs.getString('forge.files.typeDefaults'), '{".txt":"plain"}');
      expect(
        prefs.getString('forge.shortcuts.overrides'),
        '{"a.find":{"keyId":$f,"primaryModifier":true,"control":false,'
        '"shift":false,"alt":false}}',
      );
      expect(
        prefs.getString('forge.shortcuts.chordOverrides'),
        '{"a.fold":{"firstKey":{"keyId":$k,$key},'
        '"secondKey":{"keyId":$j,$key}}}',
      );
      expect(prefs.getString('forge.shortcuts.deletedBindings'), '["a.gone"]');
      expect(
        prefs.getString('forge.search.config'),
        jsonEncode(const ForgeSearchConfig(maxFileResults: 9).toJson()),
      );
      expect(prefs.getString('forge.tools.pandoc.path'), '/bin/pandoc');

      await preferences.setExternalToolPath('pandoc', '');
      expect(prefs.containsKey('forge.tools.pandoc.path'), isFalse);
    });

    test('an existing user\'s values load unchanged, the tool paths found '
        'by enumerating the keys', () async {
      SharedPreferences.setMockInitialValues({
        'forge.files.typeDefaults': '{"docx":"office","PDF":"pdf"}',
        'forge.shortcuts.deletedBindings': '["x.y"]',
        'forge.tools.office.path': '/Applications/Office.app',
        'forge.tools.pandoc_3.path': '/opt/pandoc',
        'forge.tools.empty.path': '',
        'forge.tools.Bad.path': '/nope',
        'forge.search.config': 'not json',
      });
      final preferences = ForgeKitPreferences();
      await preferences.load();
      expect(preferences.fileTypeDefaultEditors, {
        '.docx': 'office',
        '.pdf': 'pdf',
      });
      expect(preferences.deletedBindings, {'x.y'});
      expect(
        preferences.externalToolPath('office'),
        '/Applications/Office.app',
      );
      expect(preferences.externalToolPath('pandoc_3'), '/opt/pandoc');
      expect(preferences.externalToolPath('empty'), isNull);
      expect(preferences.externalToolPath('Bad'), isNull);
      expect(
        preferences.searchConfig.toJson(),
        const ForgeSearchConfig().toJson(),
      );
    });
  });

  group('ForgeFileStateStore', () {
    test('writes JSON keys indented by two spaces and text keys as they '
        'are, under .forge/', () async {
      final fs = TomMemoryFileSystem();
      final store = ForgeFileStateStore(fs);
      final document = <String, Object?>{
        'a': [1, 2.5, null],
        'b': {'c': 'ü'},
      };
      await store.write('state/x.json', document);
      await store.write('revisions/h/1.snapshot', 'line\r\n');
      expect(
        await fs.readText(fs.uriOf('.forge/state/x.json')),
        const JsonEncoder.withIndent('  ').convert(document),
      );
      expect(
        await fs.readText(fs.uriOf('.forge/revisions/h/1.snapshot')),
        'line\r\n',
      );
      expect(await store.read('state/x.json'), document);
      expect(await store.read('revisions/h/1.snapshot'), 'line\r\n');
      expect(await store.keys(), ['revisions/h/1.snapshot', 'state/x.json']);
      expect(await store.keys(prefix: 'state/'), ['state/x.json']);
      expect(
        () => store.write('revisions/h/2.snapshot', 3),
        throwsArgumentError,
      );
      await fs.writeText(fs.uriOf('.forge/state/bad.json'), '{oops');
      expect(await store.read('state/bad.json'), isNull);
      await store.write('state/x.json', null);
      expect(await fs.exists(fs.uriOf('.forge/state/x.json')), isFalse);
      expect(await store.read('state/x.json'), isNull);
    });

    test('keeps the order of the writes of one file', () async {
      final fs = TomMemoryFileSystem();
      final store = ForgeFileStateStore(fs);
      final writes = [
        for (var i = 0; i < 5; i++) store.write('k.json', {'i': i}),
      ];
      expect(await store.read('k.json'), {'i': 4});
      await Future.wait(writes);
      await store.flushed();
    });

    test('DefaultWorkspaceStateManager writes the same files, byte for byte, '
        'as the manager before the state store', () async {
      final legacyFs = TomMemoryFileSystem();
      final legacy = LegacyWorkspaceStateManager();
      expect(await legacy.initialize(legacyFs), isTrue);
      await _exercise(legacy);

      final currentFs = TomMemoryFileSystem();
      final current = DefaultWorkspaceStateManager();
      expect(await current.initialize(currentFs), isTrue);
      expect(current.stateStore, isA<ForgeFileStateStore>());
      await _exercise(current);

      final before = await _forgeFiles(legacyFs);
      final after = await _forgeFiles(currentFs);
      expect(after.keys.toList(), before.keys.toList());
      for (final key in before.keys) {
        expect(after[key], before[key], reason: key);
      }
      expect(before, hasLength(11));
      // The empty folders the manager makes at the start.
      for (final folder in ['state/editors/', 'revisions/', 'undo/']) {
        expect(
          await currentFs.exists(currentFs.uriOf('.forge/$folder')),
          isTrue,
        );
      }
      expect(await current.initialize(currentFs), isFalse);

      // And each reads what the other wrote.
      final again = DefaultWorkspaceStateManager();
      await again.initialize(legacyFs);
      final a = Uri.file('/ws/lib/a.dart');
      expect(await again.loadEditorState(a), await legacy.loadEditorState(a));
      expect(await again.listRevisions(a), await legacy.listRevisions(a));
      expect(await again.loadUndoHistory(a), await legacy.loadUndoHistory(a));
      expect(await again.loadConfig(), await legacy.loadConfig());
      expect(
        await again.loadOpenApplications(),
        await legacy.loadOpenApplications(),
      );
    });
  });

  group('Once per gesture, never before the restore', () {
    test('ForgeCoalescedStateWriter stores nothing before open, then one '
        'write per key per microtask with the last value', () async {
      final store = ForgeMemoryStateStore();
      final writer = ForgeCoalescedStateWriter(store);
      await writer.write('a', 1);
      await writer.flushed();
      expect(store.writes, isEmpty);

      writer.open();
      final done = [
        writer.write('a', 1),
        writer.write('a', 2),
        writer.write('b', 'x'),
        writer.write('a', 3),
      ];
      // A read waits for the coalesced write.
      expect(await writer.read('a'), 3);
      await Future.wait(done);
      expect(
        [for (final w in store.writes) '${w.key}=${w.value}'],
        ['a=3', 'b=x'],
      );

      await writer.write('a', 4);
      await writer.write('a', null);
      await writer.flushed();
      expect(
        [for (final w in store.writes) '${w.key}=${w.value}'],
        ['a=3', 'b=x', 'a=4', 'a=null'],
      );
    });

    test('ForgeKitPreferences: a change before load is dropped, one gesture '
        'is one write', () async {
      final platform = ThrowingPreferencesStore.install();
      addTearDown(ThrowingPreferencesStore.uninstall);
      final store = ForgeMemoryStateStore(
        initial: {'forge.shortcuts.deletedBindings': '["kept"]'},
      );
      final preferences = ForgeKitPreferences(stateStore: store);
      preferences.addDeletedBinding('early');
      await preferences.flushed();
      expect(store.writes, isEmpty);
      expect(preferences.isRestored, isFalse);

      await preferences.load();
      expect(preferences.isRestored, isTrue);
      expect(preferences.deletedBindings, {'kept'});

      preferences
        ..addDeletedBinding('one')
        ..addDeletedBinding('two')
        ..removeDeletedBinding('kept');
      await preferences.save();
      await preferences.flushed();
      expect(
        [
          for (final w in store.writes) w.key,
        ].where((k) => k == 'forge.shortcuts.deletedBindings'),
        hasLength(1),
      );
      expect(
        store.snapshot()['forge.shortcuts.deletedBindings'],
        '["one","two"]',
      );
      expect(platform.calls, 0);
    });

    test('DefaultWorkspaceStateManager: refuses before initialize, coalesces '
        'two saves of one document in a microtask', () async {
      final store = ForgeMemoryStateStore();
      final manager = DefaultWorkspaceStateManager(stateStore: store);
      final uri = Uri.file('/ws/a.txt');
      expect(
        () => manager.saveEditorState(uri, <String, dynamic>{}),
        throwsStateError,
      );
      expect(await manager.initialize(TomMemoryFileSystem()), isTrue);
      expect(manager.stateStore, same(store));

      final first = manager.saveEditorState(uri, <String, dynamic>{'v': 1});
      final second = manager.saveEditorState(uri, <String, dynamic>{'v': 2});
      await Future.wait([first, second]);
      expect(store.writes, hasLength(1));
      expect((await manager.loadEditorState(uri))?['v'], 2);

      manager.dispose();
      await manager.flushed();
      final again = DefaultWorkspaceStateManager(stateStore: store);
      expect(await again.initialize(TomMemoryFileSystem()), isFalse);
    });
  });
}
