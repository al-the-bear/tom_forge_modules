import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_specs_editor/src/agent/spec_prompt_composer.dart';

void main() {
  // An in-memory workspace with the real layout the composer reads:
  // guidelines at the workspace root, roles/quests and injected files under
  // `_ai/`.
  late TomMemoryFileSystem workspace;

  /// Writes [text] to the workspace file [path].
  Future<void> put(String path, String text) =>
      workspace.writeTextMakingFolder(workspace.uriOf(path), text);

  // A fixed clock so the `${date}` / `${time}` built-ins are deterministic.
  final clock = DateTime(2026, 6, 17, 9, 5, 3);

  SpecPromptComposer make({
    List<ChatVariable> variables = const <ChatVariable>[],
    String role = '',
    bool strict = false,
    String Function()? chatTranscript,
    String Function()? activeDocument,
  }) => SpecPromptComposer(
    workspaceName: 'tom_agent_container',
    fileSystem: workspace,
    variables: variables,
    clock: () => clock,
    role: role,
    strict: strict,
    chatTranscript: chatTranscript,
    activeDocument: activeDocument,
  );

  setUp(() => workspace = TomMemoryFileSystem());

  group('built-in placeholders (tom_specs_editor_specification.md §11.5 '
      'P1)', () {
    test(
      'quest resolves to the workspace name; date/time to the clock',
      () async {
        final composer = make(role: 'Engineer');
        expect(
          await composer.compose(r'${quest} on ${date} at ${time} as ${role}'),
          'tom_agent_container on 2026-06-17 at 09:05:03 as Engineer',
        );
      },
    );

    test('builtInsFor flags every built-in as read-only', () async {
      final builtIns = make().builtInsFor(clock);
      expect(
        builtIns.map((v) => v.name),
        containsAll(<String>['date', 'time', 'quest', 'role', 'chat', 'file']),
      );
      expect(builtIns.every((v) => v.builtIn), isTrue);
    });
  });

  group('host-context built-ins chat/file (tom_specs_editor_specification.md '
      '§11.5 P1, OE-12)', () {
    test('\${chat} resolves via the injected transcript provider', () async {
      final composer = make(chatTranscript: () => 'User: hi\nAssistant: hello');
      expect(
        await composer.compose(r'transcript:\n${chat}'),
        'transcript:\\nUser: hi\nAssistant: hello',
      );
    });

    test(
      '\${file} resolves via the injected active-document provider',
      () async {
        final composer = make(activeDocument: () => '# PD00\n\nbody');
        expect(
          await composer.compose(r'doc:\n${file}'),
          'doc:\\n# PD00\n\nbody',
        );
      },
    );

    test(
      'chat/file render empty when no provider is bound (lenient)',
      () async {
        final composer = make();
        expect(await composer.compose(r'[${chat}][${file}]'), '[][]');
      },
    );

    test('builtInsFor reflects the providers\' live values', () async {
      final builtIns = make(
        chatTranscript: () => 'T',
        activeDocument: () => 'D',
      ).builtInsFor(clock);
      String valueOf(String name) =>
          builtIns.firstWhere((v) => v.name == name).value;
      expect(valueOf('chat'), 'T');
      expect(valueOf('file'), 'D');
    });
  });

  group('chat variables (tom_specs_editor_specification.md §11.4) + alias', () {
    test(
      'a custom variable resolves via \${name} and the {{name}} alias',
      () async {
        final composer = make(
          variables: const <ChatVariable>[
            ChatVariable(name: 'project', value: 'TomSpecs'),
          ],
        );
        expect(
          await composer.compose(r'${project} / {{project}}'),
          'TomSpecs / TomSpecs',
        );
      },
    );
  });

  group('file-injection against the _ai/ folder '
      '(tom_specs_editor_specification.md §11.5 P1)', () {
    test('\${file-<relpath>} injects the file contents from _ai/', () async {
      await put('_ai/notes/brief.md', 'the brief body');
      final composer = make();
      expect(
        await composer.compose(r'context: ${file-notes/brief.md}'),
        'context: the brief body',
      );
    });

    test('a missing injected file renders empty in lenient mode', () async {
      final composer = make();
      expect(await composer.compose(r'a${file-missing.md}b'), 'ab');
    });
  });

  group('namespaced file-injection prefixes (tom_specs_editor_specification.md '
      '§11.5 P1, OE-13)', () {
    test('\${guidelines-<name>} reads _agent_guidelines/<name>.md at the '
        'workspace root', () async {
      await put('_agent_guidelines/coding.md', 'coding rules');
      final composer = make();
      expect(await composer.compose(r'${guidelines-coding}'), 'coding rules');
    });

    test('\${guidelines-<name>} accepts an explicit .md and falls back to '
        '_guidelines/', () async {
      await put('_guidelines/index.md', 'the index');
      final composer = make();
      expect(await composer.compose(r'${guidelines-index.md}'), 'the index');
    });

    test('\${role-<name>} reads _ai/roles/<name>.md (flat), then the folder '
        'layout', () async {
      await put('_ai/roles/reviewer/role.md', 'be critical');
      final composer = make();
      expect(await composer.compose(r'${role-reviewer}'), 'be critical');
    });

    test('\${quest-<type>} reads the first _ai/quests/<quest>/<type>.<quest>.* '
        'match (quest = workspace name)', () async {
      await put(
        '_ai/quests/tom_agent_container/overview.tom_agent_container.md',
        'quest overview body',
      );
      await put(
        '_ai/quests/tom_agent_container/progress.tom_agent_container.md',
        'not this one',
      );
      final composer = make();
      expect(
        await composer.compose(r'${quest-overview}'),
        'quest overview body',
      );
    });

    test(
      'a missing namespaced injection renders empty in lenient mode',
      () async {
        final composer = make();
        expect(
          await composer.compose(r'[${guidelines-x}][${role-y}][${quest-z}]'),
          '[][][]',
        );
      },
    );
  });

  group('expression form is disabled '
      '(tom_specs_editor_specification.md §11.5)', () {
    test('\${{ … }} yields the clear unsupported-error', () async {
      final composer = make();
      expect(
        () => composer.compose(r'compute ${{ 1 + 1 }}'),
        throwsA(isA<PlaceholderExpressionsUnsupportedError>()),
      );
    });
  });
}
