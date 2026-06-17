// Tests for the seven custom config editors + basic-prefs panel (step 18, §12).
//
// Done condition for step 18: each editor opens, validates, and its
// "Open raw file" button opens the backing YAML/markdown. These tests drive
// each editor over temp-file stores, asserting it renders, surfaces a
// validation error on invalid input, and routes the raw-file button to the
// backing file via the injected opener. The basic-prefs panel test covers the
// theme/font/default-app/default-profile round-trip.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_specs_editor/src/config/basic_prefs_panel.dart';
import 'package:tom_specs_editor/src/config/config_editors.dart';
import 'package:tom_specs_editor/src/config/config_specs.dart';
import 'package:tom_specs_editor/src/config/editor_preferences.dart';

/// A temp directory cleaned up after each test, used to back the stores so no
/// real workspace file is touched.
Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('specs_config');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Builds a [SpecsConfigSpecs] whose every store writes into [dir]. An
/// [agentSettings] store may be supplied to pre-seed agent settings.
SpecsConfigSpecs _specsIn(Directory dir, {AgentSettingsStore? agentSettings}) {
  String f(String name) => '${dir.path}/$name';
  return SpecsConfigSpecs(
    profiles: AgentProfileStore(File(f('profiles.yaml'))),
    promptTemplates: PromptTemplateStore(File(f('prompt_templates.yaml'))),
    queueTemplates: QueueTemplateStore(File(f('queue_templates.yaml'))),
    chatVariables: ChatVariableStore(File(f('chat_variables.yaml'))),
    timedRequests: TimedRequestStore(File(f('timed_requests.yaml'))),
    queue: PromptQueueStore(File(f('queue.yaml'))),
    agentSettings:
        agentSettings ?? AgentSettingsStore(File(f('agent_settings.yaml'))),
    preferences: EditorPreferencesStore(File(f('editor_preferences.yaml'))),
  );
}

/// Pumps an editor's main body inside a minimal app.
Future<void> _pump(WidgetTester tester, Widget body) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: body)),
  );
}

/// Registers the shared "opens" + "raw file" tests for one list editor,
/// preserving the concrete element type `T` (an unsound `<dynamic>` cast breaks
/// the spec's typed `save`/`labelOf` closures). [specs] is read lazily so the
/// per-test `setUp` store wiring applies.
void _registerListTests<T>(
  String name,
  SpecsConfigSpecs Function() specs,
  ConfigListSpec<T> Function(SpecsConfigSpecs) build,
) {
  testWidgets('$name editor opens and renders its title', (tester) async {
    final spec = build(specs());
    final editor = ConfigListEditor<T>(spec: spec, onOpenRawFile: (_) {});
    await _pump(tester, Builder(builder: editor.buildMain));
    expect(find.text(spec.title), findsOneWidget);
  });

  testWidgets('$name "Open raw file" opens the backing file', (tester) async {
    final spec = build(specs());
    Uri? opened;
    final editor =
        ConfigListEditor<T>(spec: spec, onOpenRawFile: (uri) => opened = uri);
    await _pump(tester, Builder(builder: editor.buildMain));
    await tester.tap(find.byKey(const Key('config-open-raw-file')));
    await tester.pump();
    expect(opened, Uri.file(spec.backingFile.path));
  });
}

void main() {
  group('config list editors (§12 step 18)', () {
    late Directory dir;
    late SpecsConfigSpecs specs;

    setUp(() {
      dir = _tempDir();
      specs = _specsIn(dir);
    });

    _registerListTests<QueuedPrompt>('queue', () => specs, (s) => s.queueSpec());
    _registerListTests<QueueTemplate>(
        'queue-templates', () => specs, (s) => s.queueTemplateSpec());
    _registerListTests<AgentProfile>(
        'profiles', () => specs, (s) => s.profileSpec());
    _registerListTests<PromptTemplate>(
        'prompt-templates', () => specs, (s) => s.promptTemplateSpec());
    _registerListTests<ChatVariable>(
        'chat-variables', () => specs, (s) => s.chatVariableSpec());
    _registerListTests<TimedRequest>(
        'timed-requests', () => specs, (s) => s.timedRequestSpec());

    testWidgets('a required field surfaces a validation error', (tester) async {
      // The queue editor's prompt is required; a freshly-added item is empty,
      // so selecting it must surface the validation banner.
      final spec = specs.queueSpec();
      final editor = ConfigListEditor<QueuedPrompt>(
        spec: spec,
        onOpenRawFile: (_) {},
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      await tester.tap(find.byKey(const Key('config-add')));
      await tester.pump();
      expect(find.byKey(const Key('config-validation-error')), findsOneWidget);
    });

    test('chat-variable spec flags built-in variables as read-only', () {
      final spec = specs.chatVariableSpec();
      expect(spec.isReadOnly?.call(const ChatVariable(name: 'b', builtIn: true)),
          isTrue);
      expect(spec.isReadOnly?.call(const ChatVariable(name: 'c')), isFalse);
    });

    testWidgets('a user-authored item can be removed', (tester) async {
      specs.chatVariables.save(const [ChatVariable(name: 'mine')]);
      final spec = specs.chatVariableSpec();
      final editor = ConfigListEditor<ChatVariable>(
        spec: spec,
        onOpenRawFile: (_) {},
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      await tester.tap(find.byKey(const Key('config-item-0')));
      await tester.pump();
      final remove = tester.widget<IconButton>(
        find.byKey(const Key('config-remove')),
      );
      expect(remove.onPressed, isNotNull);
    });
  });

  group('agent-settings singleton editor (§12 step 18)', () {
    testWidgets('opens and renders its title', (tester) async {
      final specs = _specsIn(_tempDir());
      final spec = specs.agentSettingsSpec();
      final editor = ConfigObjectEditor<AgentSettings>(
        spec: spec,
        onOpenRawFile: (_) {},
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      expect(find.text(spec.title), findsOneWidget);
    });

    testWidgets('an invalid port range surfaces a validation error',
        (tester) async {
      final dir = _tempDir();
      final store = AgentSettingsStore(File('${dir.path}/agent_settings.yaml'));
      // Persist a malformed range (start > end) so the editor opens invalid.
      store.save(const AgentSettings(portScanStart: 50, portScanEnd: 10));
      final spec = _specsIn(dir, agentSettings: store).agentSettingsSpec();
      final editor = ConfigObjectEditor<AgentSettings>(
        spec: spec,
        onOpenRawFile: (_) {},
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      expect(find.byKey(const Key('config-validation-error')), findsOneWidget);
    });

    testWidgets('"Open raw file" opens the backing file', (tester) async {
      final specs = _specsIn(_tempDir());
      final spec = specs.agentSettingsSpec();
      Uri? opened;
      final editor = ConfigObjectEditor<AgentSettings>(
        spec: spec,
        onOpenRawFile: (uri) => opened = uri,
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      await tester.tap(find.byKey(const Key('config-open-raw-file')));
      await tester.pump();
      expect(opened, Uri.file(spec.backingFile.path));
    });
  });

  group('basic-prefs panel (§12 — theme/font/default-app/default-profile)', () {
    testWidgets('edits flow back through the change callbacks', (tester) async {
      EditorPreferences? prefs;
      AgentSettings? settings;
      await _pump(
        tester,
        BasicPrefsPanel(
          prefs: const EditorPreferences(),
          settings: const AgentSettings(),
          profiles: const [AgentProfile(id: 'p1', name: 'Primary')],
          onPrefsChanged: (p) => prefs = p,
          onSettingsChanged: (s) => settings = s,
        ),
      );

      // Change the theme to light.
      await tester.tap(find.byKey(const Key('prefs-theme')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('light').last);
      await tester.pumpAndSettle();
      expect(prefs?.themeMode, 'light');

      // Pick the available profile as default.
      await tester.tap(find.byKey(const Key('prefs-default-profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Primary').last);
      await tester.pumpAndSettle();
      expect(settings?.defaultProfileId, 'p1');
    });
  });
}
