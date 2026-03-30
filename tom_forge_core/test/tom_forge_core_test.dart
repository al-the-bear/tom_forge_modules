import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:test/test.dart';

void main() {
  // ─── Core Types ───────────────────────────────────────────

  group('ForgeTextPosition', () {
    test('equality', () {
      const a = ForgeTextPosition(line: 1, column: 5);
      const b = ForgeTextPosition(line: 1, column: 5);
      expect(a, equals(b));
    });

    test('inequality', () {
      const a = ForgeTextPosition(line: 1, column: 5);
      const b = ForgeTextPosition(line: 2, column: 5);
      expect(a, isNot(equals(b)));
    });

    test('zero constructor', () {
      const pos = ForgeTextPosition.zero();
      expect(pos.line, 0);
      expect(pos.column, 0);
    });
  });

  group('ForgeTextRange', () {
    test('isEmpty', () {
      const range = ForgeTextRange.empty();
      expect(range.isEmpty, isTrue);
    });

    test('non-empty range', () {
      const range = ForgeTextRange(
        start: ForgeTextPosition(line: 0, column: 0),
        end: ForgeTextPosition(line: 1, column: 10),
      );
      expect(range.isEmpty, isFalse);
    });

    test('stores start and end', () {
      const range = ForgeTextRange(
        start: ForgeTextPosition(line: 3, column: 5),
        end: ForgeTextPosition(line: 7, column: 12),
      );
      expect(range.start.line, 3);
      expect(range.start.column, 5);
      expect(range.end.line, 7);
      expect(range.end.column, 12);
    });
  });

  group('ForgeSeverity', () {
    test('has all levels', () {
      expect(ForgeSeverity.values, containsAll([
        ForgeSeverity.error,
        ForgeSeverity.warning,
        ForgeSeverity.info,
        ForgeSeverity.hint,
      ]));
    });
  });

  group('ForgeDiagnostic', () {
    test('construction', () {
      final diag = ForgeDiagnostic(
        uri: Uri.parse('file:///test.dart'),
        range: const ForgeTextRange.empty(),
        message: 'test error',
        severity: ForgeSeverity.error,
        source: 'test',
      );
      expect(diag.message, 'test error');
      expect(diag.severity, ForgeSeverity.error);
      expect(diag.source, 'test');
      expect(diag.code, isNull);
    });

    test('with code', () {
      final diag = ForgeDiagnostic(
        uri: Uri.parse('file:///test.dart'),
        range: const ForgeTextRange.empty(),
        message: 'unused import',
        severity: ForgeSeverity.warning,
        source: 'analyzer',
        code: 'unused_import',
      );
      expect(diag.code, 'unused_import');
      expect(diag.toString(), contains('unused import'));
      expect(diag.toString(), contains('analyzer'));
    });
  });

  group('DiagnosticSummary', () {
    test('total', () {
      const summary = DiagnosticSummary(errors: 2, warnings: 3, infos: 1);
      expect(summary.total, 6);
    });

    test('defaults to zero', () {
      const summary = DiagnosticSummary();
      expect(summary.total, 0);
      expect(summary.errors, 0);
      expect(summary.hints, 0);
    });

    test('toString', () {
      const summary = DiagnosticSummary(
        errors: 1,
        warnings: 2,
        infos: 3,
        hints: 4,
      );
      final s = summary.toString();
      expect(s, contains('E:1'));
      expect(s, contains('W:2'));
    });
  });

  group('FileHandlingResult', () {
    test('values', () {
      expect(FileHandlingResult.values.length, 3);
    });
  });

  // ─── Enums ────────────────────────────────────────────────

  group('ForgePanelLocation', () {
    test('has all positions', () {
      expect(ForgePanelLocation.values, containsAll([
        ForgePanelLocation.left,
        ForgePanelLocation.right,
        ForgePanelLocation.bottom,
        ForgePanelLocation.middle,
      ]));
    });
  });

  group('FileChangeType', () {
    test('values', () {
      expect(FileChangeType.values, containsAll([
        FileChangeType.created,
        FileChangeType.modified,
        FileChangeType.deleted,
      ]));
    });
  });

  group('SaveReason', () {
    test('values', () {
      expect(SaveReason.values, containsAll([
        SaveReason.manual,
        SaveReason.autoSave,
        SaveReason.focusLoss,
      ]));
    });
  });

  group('ForgeProgressLocation', () {
    test('values', () {
      expect(ForgeProgressLocation.values, containsAll([
        ForgeProgressLocation.statusBar,
        ForgeProgressLocation.overlay,
      ]));
    });
  });

  // ─── Events ───────────────────────────────────────────────

  group('ConfigChangeEvent', () {
    test('construction', () {
      const event = ConfigChangeEvent(
        key: 'editor.tabSize',
        newValue: 4,
        oldValue: 2,
      );
      expect(event.key, 'editor.tabSize');
      expect(event.newValue, 4);
      expect(event.oldValue, 2);
    });

    test('null values', () {
      const event = ConfigChangeEvent(key: 'new.key');
      expect(event.newValue, isNull);
      expect(event.oldValue, isNull);
    });
  });

  group('SecretChangeEvent', () {
    test('stored', () {
      const event = SecretChangeEvent(key: 'api-key', deleted: false);
      expect(event.key, 'api-key');
      expect(event.deleted, isFalse);
    });

    test('deleted', () {
      const event = SecretChangeEvent(key: 'token', deleted: true);
      expect(event.deleted, isTrue);
    });
  });

  group('FileChangeEvent', () {
    test('construction', () {
      final event = FileChangeEvent(
        uri: Uri.parse('file:///src/main.dart'),
        type: FileChangeType.modified,
      );
      expect(event.type, FileChangeType.modified);
      expect(event.uri.path, '/src/main.dart');
    });
  });

  group('WillSaveEvent', () {
    test('construction and mutation', () {
      final event = WillSaveEvent(
        uri: Uri.parse('file:///test.txt'),
        content: 'hello',
        reason: SaveReason.manual,
      );
      expect(event.content, 'hello');
      event.content = 'modified';
      expect(event.content, 'modified');
    });
  });

  group('FocusChangeEvent', () {
    test('construction', () {
      const event = FocusChangeEvent(previous: 'a', current: 'b');
      expect(event.previous, 'a');
      expect(event.current, 'b');
    });
  });

  group('LayoutChangeEvent', () {
    test('construction', () {
      const event = LayoutChangeEvent(
        type: LayoutChangeType.panelOpened,
        panel: ForgePanelLocation.left,
      );
      expect(event.type, LayoutChangeType.panelOpened);
      expect(event.panel, ForgePanelLocation.left);
    });
  });

  // ─── Model ────────────────────────────────────────────────

  group('ForgeConfig', () {
    test('defaults', () {
      const config = ForgeConfig();
      expect(config.autoSave.enabled, isTrue);
      expect(config.autoSave.saveOnFocusLoss, isTrue);
      expect(config.autoSave.idleDelay, const Duration(seconds: 1));
    });

    test('custom autoSave', () {
      const config = ForgeConfig(
        autoSave: AutoSaveConfig(
          enabled: false,
          idleDelay: Duration(seconds: 5),
          saveOnFocusLoss: false,
        ),
      );
      expect(config.autoSave.enabled, isFalse);
      expect(config.autoSave.idleDelay.inSeconds, 5);
    });
  });

  group('ForgeStartupPreferences', () {
    test('defaults', () {
      final prefs = ForgeStartupPreferences();
      expect(prefs.rememberSettings, isTrue);
      expect(prefs.recentWorkspaces, isEmpty);
      expect(prefs.lastWorkspacePath, isNull);
    });

    test('custom values', () {
      final prefs = ForgeStartupPreferences(
        lastWorkspacePath: '/home/user/project',
        lastConfigMode: 'dark',
        recentWorkspaces: ['/a', '/b'],
      );
      expect(prefs.lastWorkspacePath, '/home/user/project');
      expect(prefs.recentWorkspaces, hasLength(2));
    });
  });

  // ─── Decoration Types ─────────────────────────────────────

  group('ForgeDecorationType', () {
    test('construction', () {
      const deco = ForgeDecorationType(
        key: 'error-underline',
        underlineStyle: ForgeUnderlineStyle.wavy,
        underlineColorValue: 0xFFFF0000,
        overviewRuler: true,
      );
      expect(deco.key, 'error-underline');
      expect(deco.underlineStyle, ForgeUnderlineStyle.wavy);
      expect(deco.overviewRuler, isTrue);
    });
  });

  group('ForgeDecorationRange', () {
    test('with hover message', () {
      const range = ForgeDecorationRange(
        range: ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 0),
          end: ForgeTextPosition(line: 0, column: 10),
        ),
        hoverMessage: 'Error here',
      );
      expect(range.hoverMessage, 'Error here');
    });
  });

  // ─── Text Editor Options ──────────────────────────────────

  group('ForgeTextEditorOptions', () {
    test('defaults', () {
      const opts = ForgeTextEditorOptions();
      expect(opts.tabSize, isNull);
      expect(opts.insertSpaces, isNull);
      expect(opts.wordWrap, isNull);
    });

    test('copyWith', () {
      const opts = ForgeTextEditorOptions(tabSize: 4, insertSpaces: true);
      final copy = opts.copyWith(wordWrap: ForgeWordWrap.on);
      expect(copy.tabSize, 4);
      expect(copy.insertSpaces, isTrue);
      expect(copy.wordWrap, ForgeWordWrap.on);
    });
  });

  // ─── Workspace Edit ───────────────────────────────────────

  group('ForgeWorkspaceEdit', () {
    test('empty edit', () {
      const edit = ForgeWorkspaceEdit();
      expect(edit.textEdits, isEmpty);
      expect(edit.fileOperations, isEmpty);
    });

    test('with text edits', () {
      final edit = ForgeWorkspaceEdit(
        textEdits: {
          Uri.parse('file:///test.dart'): [
            const ForgeTextEdit(
              range: ForgeTextRange(
                start: ForgeTextPosition(line: 0, column: 0),
                end: ForgeTextPosition(line: 0, column: 5),
              ),
              newText: 'hello',
            ),
          ],
        },
      );
      expect(edit.textEdits.length, 1);
    });
  });

  group('ForgeFileOperations', () {
    test('create', () {
      final op = ForgeCreateFileOperation(
        uri: Uri.parse('file:///new.dart'),
        content: 'void main() {}',
      );
      expect(op.content, 'void main() {}');
      expect(op.overwrite, isFalse);
    });

    test('delete', () {
      final op = ForgeDeleteFileOperation(
        uri: Uri.parse('file:///old.dart'),
      );
      expect(op.recursive, isFalse);
    });

    test('rename', () {
      final op = ForgeRenameFileOperation(
        oldUri: Uri.parse('file:///old.dart'),
        newUri: Uri.parse('file:///new.dart'),
      );
      expect(op.overwrite, isFalse);
    });
  });

  // ─── ForgeValueNotifier ───────────────────────────────────

  group('ForgeValueNotifier', () {
    test('initial value', () {
      final notifier = ForgeValueNotifier<int>(42);
      expect(notifier.value, 42);
    });

    test('set value notifies listeners', () {
      final notifier = ForgeValueNotifier<int>(0);
      var callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.value = 1;
      expect(callCount, 1);
      expect(notifier.value, 1);
    });

    test('same value does not notify', () {
      final notifier = ForgeValueNotifier<int>(5);
      var callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.value = 5;
      expect(callCount, 0);
    });

    test('removeListener stops callbacks', () {
      final notifier = ForgeValueNotifier<int>(0);
      var callCount = 0;
      void listener() => callCount++;

      notifier.addListener(listener);
      notifier.value = 1;
      expect(callCount, 1);

      notifier.removeListener(listener);
      notifier.value = 2;
      expect(callCount, 1);
    });

    test('multiple listeners', () {
      final notifier = ForgeValueNotifier<String>('a');
      var count1 = 0;
      var count2 = 0;
      notifier.addListener(() => count1++);
      notifier.addListener(() => count2++);

      notifier.value = 'b';
      expect(count1, 1);
      expect(count2, 1);
    });

    test('dispose clears listeners', () {
      final notifier = ForgeValueNotifier<int>(0);
      var callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.dispose();
      notifier.value = 99;
      expect(callCount, 0);
    });

    test('is ForgeValueListenable', () {
      final notifier = ForgeValueNotifier<int>(0);
      expect(notifier, isA<ForgeValueListenable<int>>());
    });
  });

  // ─── DefaultConfigManager ─────────────────────────────────

  group('DefaultConfigManager', () {
    test('initial config defaults', () {
      final mgr = DefaultConfigManager();
      expect(mgr.current.autoSave.enabled, isTrue);
    });

    test('custom initial config', () {
      final mgr = DefaultConfigManager(
        initial: const ForgeConfig(
          autoSave: AutoSaveConfig(enabled: false),
        ),
      );
      expect(mgr.current.autoSave.enabled, isFalse);
    });

    test('resetToDefaults emits change event', () async {
      final mgr = DefaultConfigManager(
        initial: const ForgeConfig(
          autoSave: AutoSaveConfig(enabled: false),
        ),
      );

      final future = mgr.onDidChange.first;
      mgr.resetToDefaults();
      final event = await future;
      expect(event, isA<ConfigChangeEvent>());
      expect(mgr.current.autoSave.enabled, isTrue);
    });

    test('update emits change event', () async {
      final mgr = DefaultConfigManager();
      final future = mgr.onDidChange.first;
      mgr.update((_) {});
      final event = await future;
      expect(event.key, '');
    });

    test('dispose closes stream', () {
      final mgr = DefaultConfigManager();
      mgr.dispose();
      expect(() => mgr.current, returnsNormally);
    });
  });

  // ─── DefaultProgressManager ───────────────────────────────

  group('DefaultProgressManager', () {
    test('withProgress runs task', () async {
      final mgr = DefaultProgressManager();
      final result = await mgr.withProgress(
        title: 'Test',
        location: ForgeProgressLocation.statusBar,
        task: (reporter) async {
          reporter.report(increment: 50, message: 'halfway');
          return 42;
        },
      );
      expect(result, 42);
    });

    test('progress events are emitted', () async {
      final mgr = DefaultProgressManager();
      final events = <ProgressEvent>[];
      mgr.onProgress.listen(events.add);

      await mgr.withProgress(
        title: 'Loading',
        location: ForgeProgressLocation.overlay,
        task: (reporter) async {
          reporter.report(message: 'step1');
          return null;
        },
      );

      await Future.delayed(Duration.zero);

      expect(events, isNotEmpty);
      expect(events.first.title, 'Loading');
      expect(events.first.message, 'Started');
    });

    test('withProgress propagates errors', () async {
      final mgr = DefaultProgressManager();
      expect(
        () => mgr.withProgress(
          title: 'Fail',
          location: ForgeProgressLocation.statusBar,
          task: (_) async => throw StateError('boom'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ─── DefaultOutputChannelManager ──────────────────────────

  group('DefaultOutputChannelManager', () {
    test('create and get channel', () {
      final mgr = DefaultOutputChannelManager();
      final ch = mgr.create('main');
      expect(mgr.get('main'), same(ch));
    });

    test('duplicate create returns same channel', () {
      final mgr = DefaultOutputChannelManager();
      final ch1 = mgr.create('log');
      final ch2 = mgr.create('log');
      expect(ch1, same(ch2));
    });

    test('channels list', () {
      final mgr = DefaultOutputChannelManager();
      mgr.create('a');
      mgr.create('b');
      expect(mgr.channels, hasLength(2));
    });

    test('get returns null for unknown', () {
      final mgr = DefaultOutputChannelManager();
      expect(mgr.get('missing'), isNull);
    });

    test('dispose clears channels', () {
      final mgr = DefaultOutputChannelManager();
      mgr.create('test');
      mgr.dispose();
      expect(mgr.channels, isEmpty);
    });
  });

  group('DefaultOutputChannel', () {
    test('append and appendLine', () {
      final ch = DefaultOutputChannel('test');
      ch.append('hello');
      ch.appendLine(' world');
      expect(ch.contents, contains('hello'));
      expect(ch.contents, contains('world'));
    });

    test('clear resets contents', () {
      final ch = DefaultOutputChannel('test');
      ch.appendLine('data');
      ch.clear();
      expect(ch.contents, isEmpty);
    });

    test('show/hide toggles visibility', () {
      final ch = DefaultOutputChannel('test');
      expect(ch.isVisible, isFalse);
      ch.show();
      expect(ch.isVisible, isTrue);
      ch.hide();
      expect(ch.isVisible, isFalse);
    });

    test('onDidAppend stream', () async {
      final ch = DefaultOutputChannel('test');
      final received = <String>[];
      ch.onDidAppend.listen(received.add);

      ch.append('a');
      ch.appendLine('b');
      await Future.delayed(Duration.zero);

      expect(received, ['a', 'b']);
      ch.dispose();
    });

    test('name is set', () {
      final ch = DefaultOutputChannel('myChannel');
      expect(ch.name, 'myChannel');
    });

    test('ring buffer enforces maxLines', () {
      final ch = DefaultOutputChannel('test', maxLines: 5);
      for (var i = 0; i < 10; i++) {
        ch.appendLine('line $i');
      }
      expect(ch.lines, hasLength(5));
      // Oldest lines (0-4) should be discarded.
      expect(ch.lines.first.text, 'line 5');
      expect(ch.lines.last.text, 'line 9');
    });

    test('contentsWithTimestamps includes timestamps', () {
      final ch = DefaultOutputChannel('test');
      ch.appendLine('hello');
      final ts = ch.contentsWithTimestamps;
      // Should contain a [HH:MM:SS] prefix.
      expect(ts, matches(RegExp(r'\[\d{2}:\d{2}:\d{2}\] hello')));
    });

    test('lines list stores metadata', () {
      final ch = DefaultOutputChannel('test');
      ch.appendLine('line one');
      expect(ch.lines, hasLength(1));
      expect(ch.lines.first.text, 'line one');
      expect(ch.lines.first.hasNewline, isTrue);
      expect(ch.lines.first.timestamp, isA<DateTime>());
    });

    test('append vs appendLine newline flag', () {
      final ch = DefaultOutputChannel('test');
      ch.append('no-nl');
      ch.appendLine('with-nl');
      expect(ch.lines[0].hasNewline, isFalse);
      expect(ch.lines[1].hasNewline, isTrue);
    });
  });

  // ─── DefaultSearchManager ─────────────────────────────────

  group('DefaultSearchManager', () {
    late MemoryFileSystem fs;
    late DefaultSearchManager mgr;

    setUp(() {
      fs = MemoryFileSystem(seed: {
        '/src/main.dart': 'void main() {\n  print("hello");\n}',
        '/src/util.dart': 'String greet() => "hello world";',
        '/README.md': '# Hello Project\nWelcome to hello.',
      });
      mgr = DefaultSearchManager(fileSystem: fs);
    });

    test('search finds matches across files', () async {
      final results = await mgr.search('hello');
      expect(results.length, greaterThanOrEqualTo(2));
    });

    test('case-insensitive by default', () async {
      final results = await mgr.search('Hello');
      expect(results, isNotEmpty);
    });

    test('case-sensitive search', () async {
      final results = await mgr.search('Hello', isCaseSensitive: true);
      expect(results.length, 1);
    });

    test('regex search', () async {
      final results = await mgr.search(r'print\(.*\)', isRegExp: true);
      expect(results, isNotEmpty);
      expect(results.first.matches.first.lineText, contains('print'));
    });

    test('include pattern filter', () async {
      final results = await mgr.search('hello', includePattern: '.dart');
      for (final r in results) {
        expect(r.uri.path, contains('.dart'));
      }
    });

    test('exclude pattern filter', () async {
      final results = await mgr.search('hello', excludePattern: 'README');
      for (final r in results) {
        expect(r.uri.path, isNot(contains('README')));
      }
    });

    test('maxResults limits results', () async {
      final results = await mgr.search('hello', maxResults: 1);
      expect(results.length, 1);
    });

    test('searchStream yields results', () async {
      final results = await mgr.searchStream('hello').toList();
      expect(results, isNotEmpty);
    });

    test('no matches returns empty', () async {
      final results = await mgr.search('nonexistent_xyz_12345');
      expect(results, isEmpty);
    });

    test('word match', () async {
      final results = await mgr.search('hello', isWordMatch: true);
      expect(results, isNotEmpty);
    });

    test('match ranges have correct positions', () async {
      final results = await mgr.search('void');
      expect(results, isNotEmpty);
      final match = results.first.matches.first;
      expect(match.range.start.line, 0);
      expect(match.range.start.column, 0);
      expect(match.range.end.column, 4);
    });
  });

  // ─── MemoryFileSystem ─────────────────────────────────────

  group('MemoryFileSystem', () {
    late MemoryFileSystem fs;

    setUp(() {
      fs = MemoryFileSystem(seed: {
        '/test.txt': 'hello world',
      });
    });

    test('read seeded file', () async {
      final content = await fs.read(Uri.parse('file:///test.txt'));
      expect(content, 'hello world');
    });

    test('read missing file throws', () {
      expect(
        () => fs.read(Uri.parse('file:///missing.txt')),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('readBytes', () async {
      final bytes = await fs.readBytes(Uri.parse('file:///test.txt'));
      expect(bytes, isNotEmpty);
    });

    test('write creates new file', () async {
      await fs.write(Uri.parse('file:///new.txt'), 'content');
      final content = await fs.read(Uri.parse('file:///new.txt'));
      expect(content, 'content');
    });

    test('write emits created event for new file', () async {
      final future = fs.onDidChange.first;
      await fs.write(Uri.parse('file:///brand_new.txt'), 'data');
      final event = await future;
      expect(event.type, FileChangeType.created);
    });

    test('write emits modified event for existing file', () async {
      final future = fs.onDidChange.first;
      await fs.write(Uri.parse('file:///test.txt'), 'updated');
      final event = await future;
      expect(event.type, FileChangeType.modified);
    });

    test('delete removes file', () async {
      await fs.delete(Uri.parse('file:///test.txt'));
      expect(await fs.exists(Uri.parse('file:///test.txt')), isFalse);
    });

    test('delete emits event', () async {
      final future = fs.onDidChange.first;
      await fs.delete(Uri.parse('file:///test.txt'));
      final event = await future;
      expect(event.type, FileChangeType.deleted);
    });

    test('exists returns true for seeded file', () async {
      expect(await fs.exists(Uri.parse('file:///test.txt')), isTrue);
    });

    test('exists returns false for missing file', () async {
      expect(await fs.exists(Uri.parse('file:///nope.txt')), isFalse);
    });

    test('stat returns size', () async {
      final stat = await fs.stat(Uri.parse('file:///test.txt'));
      expect(stat.size, greaterThan(0));
    });

    test('list returns directory content', () async {
      fs = MemoryFileSystem(seed: {
        '/dir/a.txt': 'a',
        '/dir/b.txt': 'b',
        '/dir/sub/c.txt': 'c',
      });
      final entries = await fs.list(Uri.parse('file:///dir'));
      expect(entries.length, greaterThanOrEqualTo(2));
    });

    test('list recursive', () async {
      fs = MemoryFileSystem(seed: {
        '/dir/a.txt': 'a',
        '/dir/sub/b.txt': 'b',
      });
      final entries = await fs.list(Uri.parse('file:///dir'), recursive: true);
      expect(entries.length, greaterThanOrEqualTo(2));
    });

    test('save triggers onWillSave and onDidSave', () async {
      final willSaveFuture = fs.onWillSave.first;
      final didSaveFuture = fs.onDidSave.first;

      await fs.save(Uri.parse('file:///test.txt'));

      final willSave = await willSaveFuture;
      final didSave = await didSaveFuture;
      expect(willSave.reason, SaveReason.manual);
      expect(didSave.path, '/test.txt');
    });

    test('applyWorkspaceEdit modifies file', () async {
      final edit = ForgeWorkspaceEdit(
        textEdits: {
          Uri.parse('file:///test.txt'): [
            const ForgeTextEdit(
              range: ForgeTextRange(
                start: ForgeTextPosition(line: 0, column: 0),
                end: ForgeTextPosition(line: 0, column: 5),
              ),
              newText: 'HELLO',
            ),
          ],
        },
      );
      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isTrue);

      final content = await fs.read(Uri.parse('file:///test.txt'));
      expect(content, 'HELLO world');
    });

    test('applyWorkspaceEdit on missing file skips', () async {
      final edit = ForgeWorkspaceEdit(
        textEdits: {
          Uri.parse('file:///missing.txt'): [
            const ForgeTextEdit(
              range: ForgeTextRange.empty(),
              newText: 'ignored',
            ),
          ],
        },
      );
      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isTrue);
    });

    test('paths returns all file paths', () {
      expect(fs.paths, contains('/test.txt'));
    });

    test('dispose closes streams', () {
      fs.dispose();
    });
  });

  // ─── DefaultDiagnosticManager ─────────────────────────────

  group('DefaultDiagnosticManager', () {
    late DefaultDiagnosticManager mgr;

    setUp(() {
      mgr = DefaultDiagnosticManager();
    });

    tearDown(() {
      mgr.dispose();
    });

    test('createCollection returns collection', () {
      final coll = mgr.createCollection('test');
      expect(coll.name, 'test');
    });

    test('all diagnostics starts empty', () {
      expect(mgr.all, isEmpty);
    });

    test('adding diagnostics updates all', () {
      final coll = mgr.createCollection('analyzer');
      coll.set(Uri.parse('file:///test.dart'), [
        ForgeDiagnostic(
          uri: Uri.parse('file:///test.dart'),
          range: const ForgeTextRange.empty(),
          message: 'error',
          severity: ForgeSeverity.error,
          source: 'dart',
        ),
      ]);
      expect(mgr.all, hasLength(1));
    });

    test('forUri filters by uri', () {
      final coll = mgr.createCollection('dart');
      final uri1 = Uri.parse('file:///a.dart');
      final uri2 = Uri.parse('file:///b.dart');

      coll.set(uri1, [
        ForgeDiagnostic(
          uri: uri1,
          range: const ForgeTextRange.empty(),
          message: 'a-error',
          severity: ForgeSeverity.error,
          source: 'dart',
        ),
      ]);
      coll.set(uri2, [
        ForgeDiagnostic(
          uri: uri2,
          range: const ForgeTextRange.empty(),
          message: 'b-warning',
          severity: ForgeSeverity.warning,
          source: 'dart',
        ),
      ]);

      expect(mgr.forUri(uri1), hasLength(1));
      expect(mgr.forUri(uri1).first.message, 'a-error');
      expect(mgr.forUri(uri2).first.message, 'b-warning');
    });

    test('collection clear removes diagnostics', () {
      final coll = mgr.createCollection('test');
      coll.set(Uri.parse('file:///t.dart'), [
        ForgeDiagnostic(
          uri: Uri.parse('file:///t.dart'),
          range: const ForgeTextRange.empty(),
          message: 'msg',
          severity: ForgeSeverity.info,
          source: 's',
        ),
      ]);
      expect(mgr.all, hasLength(1));

      coll.clear();
      expect(mgr.all, isEmpty);
    });

    test('collection delete removes for specific uri', () {
      final coll = mgr.createCollection('test');
      final uri = Uri.parse('file:///x.dart');
      coll.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          range: const ForgeTextRange.empty(),
          message: 'msg',
          severity: ForgeSeverity.hint,
          source: 's',
        ),
      ]);
      coll.delete(uri);
      expect(mgr.all, isEmpty);
    });

    test('allNotifier updates on changes', () {
      var notified = false;
      mgr.allNotifier.addListener(() => notified = true);

      final coll = mgr.createCollection('test');
      coll.set(Uri.parse('file:///t.dart'), [
        ForgeDiagnostic(
          uri: Uri.parse('file:///t.dart'),
          range: const ForgeTextRange.empty(),
          message: 'err',
          severity: ForgeSeverity.error,
          source: 's',
        ),
      ]);
      expect(notified, isTrue);
    });

    test('multiple collections aggregate', () {
      final coll1 = mgr.createCollection('dart');
      final coll2 = mgr.createCollection('yaml');
      final uri = Uri.parse('file:///config.yaml');

      coll1.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          range: const ForgeTextRange.empty(),
          message: 'dart-err',
          severity: ForgeSeverity.error,
          source: 'dart',
        ),
      ]);
      coll2.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          range: const ForgeTextRange.empty(),
          message: 'yaml-warn',
          severity: ForgeSeverity.warning,
          source: 'yaml',
        ),
      ]);

      expect(mgr.all, hasLength(2));
      expect(mgr.forUri(uri), hasLength(2));
    });
  });

  // ─── DefaultNotificationManager ───────────────────────────

  group('DefaultNotificationManager', () {
    late DefaultNotificationManager mgr;

    setUp(() {
      mgr = DefaultNotificationManager(
        autoDismissDuration: const Duration(seconds: 60),
      );
    });

    tearDown(() {
      mgr.dispose();
    });

    test('showInformation adds notification', () {
      mgr.showInformation('test message');
      expect(mgr.notifications.value, hasLength(1));
      expect(mgr.notifications.value.first.severity,
          NotificationSeverity.info);
    });

    test('showWarning adds warning', () {
      mgr.showWarning('warn');
      expect(mgr.notifications.value.first.severity,
          NotificationSeverity.warning);
    });

    test('showError adds error', () {
      mgr.showError('err');
      expect(mgr.notifications.value.first.severity,
          NotificationSeverity.error);
    });

    test('remove dismisses notification', () {
      mgr.showInformation('msg');
      final item = mgr.notifications.value.first;
      mgr.remove(item);
      expect(mgr.notifications.value, isEmpty);
    });

    test('notification response completes on dismiss', () async {
      final future = mgr.showInformation('msg', actions: ['OK']);
      final item = mgr.notifications.value.first;
      item.dismiss('OK');
      final result = await future;
      expect(result, 'OK');
    });

    test('notification response null on auto-dismiss', () async {
      final future = mgr.showInformation('msg');
      final item = mgr.notifications.value.first;
      item.dismiss();
      final result = await future;
      expect(result, isNull);
    });

    test('notifications notifier fires on change', () {
      var notified = false;
      mgr.notifications.addListener(() => notified = true);
      mgr.showInformation('trigger');
      expect(notified, isTrue);
    });

    test('multiple notifications', () {
      mgr.showInformation('a');
      mgr.showWarning('b');
      mgr.showError('c');
      expect(mgr.notifications.value, hasLength(3));
    });
  });

  group('NotificationItem', () {
    test('construction', () {
      final item = NotificationItem(
        message: 'test',
        severity: NotificationSeverity.info,
      );
      expect(item.message, 'test');
      expect(item.severity, NotificationSeverity.info);
      expect(item.actions, isEmpty);
      expect(item.createdAt, isA<DateTime>());
    });

    test('dismiss completes response', () async {
      final item = NotificationItem(
        message: 'test',
        severity: NotificationSeverity.warning,
        actions: ['Yes', 'No'],
      );
      item.dismiss('Yes');
      expect(await item.response, 'Yes');
    });

    test('double dismiss is safe', () {
      final item = NotificationItem(
        message: 'test',
        severity: NotificationSeverity.error,
      );
      item.dismiss();
      item.dismiss('second');
    });
  });

  // ─── DefaultUndoManager ───────────────────────────────────

  group('DefaultUndoManager', () {
    late DefaultUndoManager mgr;

    setUp(() {
      mgr = DefaultUndoManager();
    });

    tearDown(() {
      mgr.dispose();
    });

    test('initially cannot undo or redo', () {
      expect(mgr.canUndo.value, isFalse);
      expect(mgr.canRedo.value, isFalse);
    });

    test('push enables undo', () {
      mgr.push(UndoEntry(
        undo: () async {},
        redo: () async {},
        label: 'test',
      ));
      expect(mgr.canUndo.value, isTrue);
      expect(mgr.canRedo.value, isFalse);
    });

    test('undo calls entry.undo and enables redo', () async {
      var undoCalled = false;
      mgr.push(UndoEntry(
        undo: () async => undoCalled = true,
        redo: () async {},
      ));

      await mgr.undo();
      expect(undoCalled, isTrue);
      expect(mgr.canUndo.value, isFalse);
      expect(mgr.canRedo.value, isTrue);
    });

    test('redo calls entry.redo', () async {
      var redoCalled = false;
      mgr.push(UndoEntry(
        undo: () async {},
        redo: () async => redoCalled = true,
      ));

      await mgr.undo();
      await mgr.redo();
      expect(redoCalled, isTrue);
      expect(mgr.canUndo.value, isTrue);
      expect(mgr.canRedo.value, isFalse);
    });

    test('push clears redo stack', () async {
      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      await mgr.undo();
      expect(mgr.canRedo.value, isTrue);

      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      expect(mgr.canRedo.value, isFalse);
    });

    test('clear resets stacks', () {
      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      mgr.clear();
      expect(mgr.canUndo.value, isFalse);
      expect(mgr.canRedo.value, isFalse);
    });

    test('undo on empty stack is no-op', () async {
      await mgr.undo();
      expect(mgr.canUndo.value, isFalse);
    });

    test('redo on empty stack is no-op', () async {
      await mgr.redo();
      expect(mgr.canRedo.value, isFalse);
    });

    test('canUndo notifier fires on state change', () {
      var notified = false;
      mgr.canUndo.addListener(() => notified = true);
      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      expect(notified, isTrue);
    });

    test('multiple undo/redo operations', () async {
      mgr.push(UndoEntry(
        undo: () async {},
        redo: () async {},
        label: 'op1',
      ));
      mgr.push(UndoEntry(
        undo: () async {},
        redo: () async {},
        label: 'op2',
      ));

      expect(mgr.canUndo.value, isTrue);

      await mgr.undo();
      expect(mgr.canUndo.value, isTrue);
      expect(mgr.canRedo.value, isTrue);

      await mgr.undo();
      expect(mgr.canUndo.value, isFalse);
      expect(mgr.canRedo.value, isTrue);

      await mgr.redo();
      expect(mgr.canUndo.value, isTrue);
    });
  });

  group('UndoEntry', () {
    test('construction', () {
      final entry = UndoEntry(
        undo: () async {},
        redo: () async {},
        label: 'test',
      );
      expect(entry.label, 'test');
    });

    test('label is optional', () {
      final entry = UndoEntry(
        undo: () async {},
        redo: () async {},
      );
      expect(entry.label, isNull);
    });
  });
}
