// Tests for the seven custom config editors (step 18,
// `tom_specs_editor_specification.md` §12).
//
// Done condition for step 18: each editor opens, validates, and its
// "Open raw file" button opens the backing YAML/markdown. These tests drive
// each editor over agent stores in an in-memory workspace, asserting it renders, surfaces a
// validation error on invalid input, and routes the raw-file button to the
// backing file via the injected opener. The basic preferences are a
// configuration description (basic_preferences_configuration_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_specs_editor/src/config/config_editors.dart';
import 'package:tom_specs_editor/src/config/config_field.dart';
import 'package:tom_specs_editor/src/config/config_specs.dart';

/// A [SpecsConfigSpecs] whose every store lives in [fs] (a fresh in-memory
/// workspace unless given), so no real workspace file is touched.
SpecsConfigSpecs _specsIn([TomFileSystem? fs]) =>
    SpecsConfigSpecs(fileSystem: fs ?? TomMemoryFileSystem());

/// Pumps an editor's main body inside a minimal app, and a frame more for
/// the editor's first read of its store.
Future<void> _pump(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.pump();
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
    final editor = ConfigListEditor<T>(spec: spec, onOpenRawFile: (_) async {});
    await _pump(tester, Builder(builder: editor.buildMain));
    expect(find.text(spec.title), findsOneWidget);
  });

  testWidgets('$name "Open raw file" opens the backing file', (tester) async {
    final spec = build(specs());
    Uri? opened;
    final editor = ConfigListEditor<T>(
      spec: spec,
      onOpenRawFile: (uri) async => opened = uri,
    );
    await _pump(tester, Builder(builder: editor.buildMain));
    await tester.tap(find.byKey(const Key('config-open-raw-file')));
    await tester.pump();
    expect(opened, spec.backingUri);
  });
}

void main() {
  group('config list editors (tom_specs_editor_specification.md §12 '
      'step 18)', () {
    late SpecsConfigSpecs specs;

    setUp(() => specs = _specsIn());

    _registerListTests<QueuedPrompt>(
      'queue',
      () => specs,
      (s) => s.queueSpec(),
    );
    _registerListTests<QueueTemplate>(
      'queue-templates',
      () => specs,
      (s) => s.queueTemplateSpec(),
    );
    _registerListTests<AgentProfile>(
      'profiles',
      () => specs,
      (s) => s.profileSpec(),
    );
    _registerListTests<PromptTemplate>(
      'prompt-templates',
      () => specs,
      (s) => s.promptTemplateSpec(),
    );
    _registerListTests<ChatVariable>(
      'chat-variables',
      () => specs,
      (s) => s.chatVariableSpec(),
    );
    _registerListTests<TimedRequest>(
      'timed-requests',
      () => specs,
      (s) => s.timedRequestSpec(),
    );

    testWidgets('a required field surfaces a validation error', (tester) async {
      // The queue editor's prompt is required; a freshly-added item is empty,
      // so selecting it must surface the validation banner.
      final spec = specs.queueSpec();
      final editor = ConfigListEditor<QueuedPrompt>(
        spec: spec,
        onOpenRawFile: (_) async {},
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      await tester.tap(find.byKey(const Key('config-add')));
      await tester.pump();
      expect(find.byKey(const Key('config-validation-error')), findsOneWidget);
    });

    testWidgets(
      'the prompt-templates editor shows a live placeholder preview when a '
      'composer is wired (tom_specs_editor_specification.md §12, OE-14)',
      (tester) async {
        // A composer that uppercases a known placeholder, so the preview's
        // expansion is visibly distinct from the raw body.
        final specsWithCompose = _specsIn().withCompose(
          (s) async => s.replaceAll(r'${who}', 'Alex'),
        );
        await specsWithCompose.promptTemplates.save([
          PromptTemplate(id: 't1', name: 'Greeting', body: r'hi ${who}'),
        ]);
        final spec = specsWithCompose.promptTemplateSpec();
        final editor = ConfigListEditor<PromptTemplate>(
          spec: spec,
          onOpenRawFile: (_) async {},
        );
        await _pump(tester, Builder(builder: editor.buildMain));
        await tester.tap(find.byKey(const Key('config-item-0')));
        await tester.pump();
        await tester.pump(); // the expansion completes
        // The preview field expands the body's placeholder.
        expect(find.text('hi Alex'), findsOneWidget);
      },
    );

    test('the preview field is omitted when no composer is wired', () {
      // Default `specs` has compose == null, so the prompt-template form keeps
      // only its three authored fields (name, body, user-message toggle).
      expect(specs.promptTemplateSpec().fields, hasLength(3));
    });

    testWidgets('a field renders its contextual help caption '
        '(tom_specs_editor_specification.md §12, OE-15)', (tester) async {
      final field = ConfigField<String>.text(
        label: 'Name',
        help: 'Helpful note.',
        get: (v) => v,
        set: (v, t) => t,
      );
      await _pump(
        tester,
        Builder(builder: (_) => field.buildField('x', (_) {})),
      );
      expect(find.text('Helpful note.'), findsOneWidget);
      expect(find.byKey(const ValueKey('cfg-help-Name')), findsOneWidget);
    });

    testWidgets('a field without help renders no help caption '
        '(tom_specs_editor_specification.md §12, OE-15)', (tester) async {
      final field = ConfigField<String>.text(
        label: 'Name',
        get: (v) => v,
        set: (v, t) => t,
      );
      await _pump(
        tester,
        Builder(builder: (_) => field.buildField('x', (_) {})),
      );
      expect(find.byKey(const ValueKey('cfg-help-Name')), findsNothing);
    });

    testWidgets('an authored field help string renders in the editor '
        '(tom_specs_editor_specification.md §12, OE-15)', (tester) async {
      // Every config editor authors per-field help; the queue's Prompt field is
      // a representative one. It shows once an item is selected.
      final spec = specs.queueSpec();
      expect(
        spec.fields.first.help,
        isNotNull,
        reason: 'the Prompt field must author help text',
      );
      final editor = ConfigListEditor<QueuedPrompt>(
        spec: spec,
        onOpenRawFile: (_) async {},
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      await tester.tap(find.byKey(const Key('config-add')));
      await tester.pump();
      expect(find.byKey(const ValueKey('cfg-help-Prompt')), findsOneWidget);
    });

    test('chat-variable spec flags built-in variables as read-only', () {
      final spec = specs.chatVariableSpec();
      expect(
        spec.isReadOnly?.call(const ChatVariable(name: 'b', builtIn: true)),
        isTrue,
      );
      expect(spec.isReadOnly?.call(const ChatVariable(name: 'c')), isFalse);
    });

    testWidgets('a user-authored item can be removed', (tester) async {
      await specs.chatVariables.save(const [ChatVariable(name: 'mine')]);
      final spec = specs.chatVariableSpec();
      final editor = ConfigListEditor<ChatVariable>(
        spec: spec,
        onOpenRawFile: (_) async {},
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

  group('agent-settings singleton editor '
      '(tom_specs_editor_specification.md §12 step 18)', () {
    testWidgets('opens and renders its title', (tester) async {
      final specs = _specsIn();
      final spec = specs.agentSettingsSpec();
      final editor = ConfigObjectEditor<AgentSettings>(
        spec: spec,
        onOpenRawFile: (_) async {},
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      expect(find.text(spec.title), findsOneWidget);
    });

    testWidgets('an invalid port range surfaces a validation error', (
      tester,
    ) async {
      final specs = _specsIn();
      // Persist a malformed range (start > end) so the editor opens invalid.
      await specs.agentSettings.save(
        const AgentSettings(portScanStart: 50, portScanEnd: 10),
      );
      final spec = specs.agentSettingsSpec();
      final editor = ConfigObjectEditor<AgentSettings>(
        spec: spec,
        onOpenRawFile: (_) async {},
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      expect(find.byKey(const Key('config-validation-error')), findsOneWidget);
    });

    testWidgets('"Open raw file" opens the backing file', (tester) async {
      final specs = _specsIn();
      final spec = specs.agentSettingsSpec();
      Uri? opened;
      final editor = ConfigObjectEditor<AgentSettings>(
        spec: spec,
        onOpenRawFile: (uri) async => opened = uri,
      );
      await _pump(tester, Builder(builder: editor.buildMain));
      await tester.tap(find.byKey(const Key('config-open-raw-file')));
      await tester.pump();
      expect(opened, spec.backingUri);
    });
  });
}
