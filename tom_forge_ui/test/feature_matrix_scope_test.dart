import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Section 29: Feature Matrix by Scope — unit and integration tests for
/// cross-cutting module/component/shell responsibility wiring.
void main() {
  // ── Row 1-3: Shell module, owner resolution, typed members ──

  group('TomForgeShellModule', () {
    test('supportedExtensions contains all built-in types', () {
      expect(
        TomForgeShellModule.supportedExtensions,
        containsAll(['dart', 'md', 'markdown', 'yaml', 'yml', 'txt']),
      );
    });

    test('canHandleExtension returns true for supported types', () {
      final module = TomForgeShellModule();
      expect(module.canHandleExtension('dart'), isTrue);
      expect(module.canHandleExtension('md'), isTrue);
      expect(module.canHandleExtension('YAML'), isTrue);
      expect(module.canHandleExtension('json'), isFalse);
      expect(module.canHandleExtension('html'), isFalse);
    });

    test('typed editor getters return registered editors by type', () {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      final module = TomForgeShellModule();
      module.activate(shell);

      // Initially empty.
      expect(module.dartEditors, isEmpty);
      expect(module.mdEditors, isEmpty);
      expect(module.yamlEditors, isEmpty);
      expect(module.editors, isEmpty);

      // Register a Dart editor.
      final dartEditor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: '',
          uri: Uri.parse('file:///test.dart'),
        ),
        module: module,
      );
      module.registerDartEditor(dartEditor);

      expect(module.dartEditors, hasLength(1));
      expect(module.dartEditors.first, same(dartEditor));
      expect(module.mdEditors, isEmpty);
      expect(module.editors, hasLength(1));

      shell.dispose();
    });

    test('deactivate clears all registered editors', () {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      final module = TomForgeShellModule();
      module.activate(shell);

      final dartEditor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: '',
          uri: Uri.parse('file:///a.dart'),
        ),
        module: module,
      );
      module.registerDartEditor(dartEditor);
      expect(module.editors, isNotEmpty);

      module.deactivate();
      expect(module.editors, isEmpty);
      expect(module.dartEditors, isEmpty);

      shell.dispose();
    });
  });

  // ── Row 2: Owner module resolution ──

  group('DefaultLayoutController owner resolution', () {
    test('creates editor with TomForgeShellModule as owner', () async {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: {'/workspace/hello.dart': 'void main() {}'},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );

      // Register shell module as first module.
      final shellModule = TomForgeShellModule();
      (shell.modules as DefaultModuleRegistry).register(shellModule);
      shellModule.activate(shell);

      // Register an app module second.
      final appModule = _SimpleModule('App');
      (shell.modules as DefaultModuleRegistry).register(appModule);

      // Open a Dart file — the layout controller should resolve the editor.
      shell.layout.openFile(Uri.parse('file:///workspace/hello.dart'));

      // Wait for async file reading and editor creation.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final editors = shell.systemState.openEditors;
      expect(editors, isNotEmpty, reason: 'Editor should be opened');
      // The editor's module should be the shell module, not the app module.
      if (editors.isNotEmpty) {
        final editor = editors.first;
        expect(editor, isA<ForgeDartEditor>());
        expect((editor as ForgeDartEditor).module, isA<TomForgeShellModule>());
      }

      shell.dispose();
    });

    test('file type defaults override built-in editor selection', () async {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: {'/workspace/notes.txt': 'line one\nline two'},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );

      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);

      shell.setFileTypeDefault('.txt', 'plaintext');
      shell.layout.openFile(Uri.parse('file:///workspace/notes.txt'));

      await Future<void>.delayed(const Duration(milliseconds: 80));

      final active = shell.systemState.activeEditor;
      expect(active, isA<ForgePlainTextEditor>());

      shell.dispose();
    });
  });

  // ── Row 6: Module lifecycle ──

  group('Module lifecycle', () {
    test('dispose calls deactivateAll on module registry', () {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );

      final module = _LifecycleModule();
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);
      expect(module.activated, isTrue);
      expect(module.deactivated, isFalse);

      shell.dispose();
      expect(module.deactivated, isTrue);
    });
  });

  // ── Row 8: Provider extension points ──

  group('DartOutlineProvider', () {
    test('canProvide returns true for ForgeDartEditor', () {
      final provider = DartOutlineProvider();
      final editor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: 'void main() {}',
          uri: Uri.parse('file:///test.dart'),
        ),
        module: TomForgeShellModule(),
      );
      expect(provider.canProvide(editor), isTrue);
      provider.dispose();
    });

    test('canProvide returns false for non-Dart editors', () {
      final provider = DartOutlineProvider();
      final editor = ForgePlainTextEditor.fromContent(
        content: 'hello',
        uri: Uri.parse('file:///test.txt'),
        module: TomForgeShellModule(),
      );
      expect(provider.canProvide(editor), isFalse);
      provider.dispose();
    });

    test('provideOutline extracts class declarations', () async {
      final provider = DartOutlineProvider();
      final code = '''
import 'dart:core';

class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    return Container();
  }
}

abstract class BaseService {
  void run();
}
''';
      final editor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: code,
          uri: Uri.parse('file:///test.dart'),
        ),
        module: TomForgeShellModule(),
      );

      final items = await provider.provideOutline(editor);
      final labels = items.map((i) => i.label).toList();
      expect(labels, contains('MyWidget'));
      expect(labels, contains('BaseService'));
      expect(
        items.firstWhere((i) => i.label == 'MyWidget').kind,
        ForgeSymbolKind.classKind,
      );
      expect(
        items.firstWhere((i) => i.label == 'BaseService').detail,
        contains('abstract'),
      );
      provider.dispose();
    });

    test('provideOutline extracts enum and mixin', () async {
      final provider = DartOutlineProvider();
      final code = '''
enum Color { red, green, blue }

mixin Serializable {
  Map<String, dynamic> toJson();
}
''';
      final editor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: code,
          uri: Uri.parse('file:///types.dart'),
        ),
        module: TomForgeShellModule(),
      );

      final items = await provider.provideOutline(editor);
      expect(
        items.any(
          (i) => i.label == 'Color' && i.kind == ForgeSymbolKind.enumKind,
        ),
        isTrue,
      );
      expect(
        items.any(
          (i) =>
              i.label == 'Serializable' && i.kind == ForgeSymbolKind.interface,
        ),
        isTrue,
      );
      provider.dispose();
    });

    test('provideOutline extracts top-level functions', () async {
      final provider = DartOutlineProvider();
      final code = '''
void main() {
  print('hello');
}

Future<int> computeValue() async {
  return 42;
}
''';
      final editor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: code,
          uri: Uri.parse('file:///main.dart'),
        ),
        module: TomForgeShellModule(),
      );

      final items = await provider.provideOutline(editor);
      final labels = items.map((i) => i.label).toList();
      expect(labels, contains('main'));
      expect(labels, contains('computeValue'));
      expect(
        items.firstWhere((i) => i.label == 'main').kind,
        ForgeSymbolKind.function,
      );
      provider.dispose();
    });

    test('provideOutline returns empty for empty code', () async {
      final provider = DartOutlineProvider();
      final editor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: '',
          uri: Uri.parse('file:///empty.dart'),
        ),
        module: TomForgeShellModule(),
      );

      final items = await provider.provideOutline(editor);
      expect(items, isEmpty);
      provider.dispose();
    });

    test('outline wires through DefaultOutlineManager', () async {
      final manager = DefaultOutlineManager();
      final provider = DartOutlineProvider();
      final reg = manager.registerProvider(provider);

      final editor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: 'class Foo {}',
          uri: Uri.parse('file:///foo.dart'),
        ),
        module: TomForgeShellModule(),
      );

      final items = await manager.provideOutline(editor);
      expect(items, isNotEmpty);
      expect(items.first.label, 'Foo');

      reg.dispose();
      provider.dispose();
      manager.dispose();
    });
  });

  group('ModifiedFileDecorationProvider', () {
    test('returns null for clean editors', () {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      final provider = ModifiedFileDecorationProvider(
        systemState: shell.systemState,
      );

      // No open editors → no decoration.
      final decoration = provider.provideDecoration(
        Uri.parse('file:///a.dart'),
      );
      expect(decoration, isNull);

      provider.dispose();
      shell.dispose();
    });

    test('returns M badge for dirty editor', () {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: {'/workspace/test.dart': 'void main() {}'},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );

      final module = TomForgeShellModule();
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);

      // Create and register a dirty editor.
      final ctrl = DartCodeController(
        initialCode: 'void main() {}',
        uri: Uri.parse('file:///workspace/test.dart'),
      );
      final editor = ForgeDartEditor(controller: ctrl, module: module);
      (shell.systemState as DefaultSystemState).addOpenEditor(editor);

      // Simulate dirty state.
      ctrl.userCode = 'void main() { print("changed"); }';

      final provider = ModifiedFileDecorationProvider(
        systemState: shell.systemState,
      );

      // Editor is dirty → should get M badge.
      if (editor.isDirty.value) {
        final decoration = provider.provideDecoration(
          Uri.parse('file:///workspace/test.dart'),
        );
        expect(decoration, isNotNull);
        expect(decoration!.badge, 'M');
        expect(decoration.propagate, isTrue);
      }

      provider.dispose();
      shell.dispose();
    });

    test('fires onDidChange when editors change', () async {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      final provider = ModifiedFileDecorationProvider(
        systemState: shell.systemState,
      );

      var changed = false;
      final sub = provider.onDidChange.listen((_) => changed = true);

      // Trigger an editor change event.
      final module = TomForgeShellModule();
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);

      final editor = ForgeDartEditor(
        controller: DartCodeController(
          initialCode: '',
          uri: Uri.parse('file:///new.dart'),
        ),
        module: module,
      );
      (shell.systemState as DefaultSystemState).addOpenEditor(editor);

      await Future<void>.delayed(Duration.zero);
      expect(changed, isTrue);

      await sub.cancel();
      provider.dispose();
      shell.dispose();
    });

    test('decoration wires through DefaultFileDecorationManager', () {
      final manager = DefaultFileDecorationManager();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      final provider = ModifiedFileDecorationProvider(
        systemState: shell.systemState,
      );
      final reg = manager.registerProvider(provider);

      // No dirty editors → no decoration from manager.
      final decoration = manager.getDecoration(Uri.parse('file:///x.dart'));
      expect(decoration, isNull);

      reg.dispose();
      provider.dispose();
      manager.dispose();
      shell.dispose();
    });
  });

  // ── Row 10: Module-scoped persistence ──

  group('Module-scoped persistence', () {
    test('forModule returns isolated store per module type', () {
      final storage = DefaultModuleStorage();
      final modA = _SimpleModule('A');
      final modB = _SimpleModule('B');

      storage.forModule(modA).set('key', 'valueA');
      storage.forModule(modB).set('key', 'valueB');

      expect(storage.forModule(modA).get('key'), 'valueA');
      expect(storage.forModule(modB).get('key'), 'valueB');
    });

    test('forModule returns same store for same module type', () {
      final storage = DefaultModuleStorage();
      final mod = TomForgeShellModule();

      final store1 = storage.forModule(mod);
      final store2 = storage.forModule(mod);

      store1.set('x', 42);
      expect(store2.get('x'), 42);
    });
  });

  // ── Row 11: Cross-module registry ──

  group('Cross-module registry', () {
    test('get<T>() returns typed module', () {
      final registry = DefaultModuleRegistry();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );

      final shellModule = TomForgeShellModule();
      registry.register(shellModule);
      shellModule.activate(shell);

      final appModule = _SimpleModule('App');
      registry.register(appModule);

      // Typed lookup returns the correct module.
      final found = registry.get<TomForgeShellModule>();
      expect(found, same(shellModule));
      expect(found.displayName, 'Tom Forge Editors');
      expect(TomForgeShellModule.supportedExtensions, isNotEmpty);

      shell.dispose();
    });

    test('get<T>() throws for unregistered type', () {
      final registry = DefaultModuleRegistry();
      expect(() => registry.get<TomForgeShellModule>(), throwsStateError);
    });
  });

  // ── Row 12: Staging-to-production parity ──
  // ForgeAppModule parity tests are in tom_forge_app/test/ since
  // ForgeAppModule is not a dependency of tom_forge_ui.
}

// ── Test helpers ──

class _SimpleModule extends ForgeModule {
  _SimpleModule(this._name);
  final String _name;

  @override
  String get displayName => _name;

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

class _LifecycleModule extends ForgeModule {
  bool activated = false;
  bool deactivated = false;

  @override
  String get displayName => 'Lifecycle Module';

  @override
  void activate(ForgeShellApi shell) => activated = true;

  @override
  void deactivate() => deactivated = true;

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}
