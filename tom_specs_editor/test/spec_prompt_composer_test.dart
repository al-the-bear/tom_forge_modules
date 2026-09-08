import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_specs_editor/src/agent/spec_prompt_composer.dart';

void main() {
  // A workspace root with an `_ai/` subfolder, mirroring the real layout the
  // composer assumes (aiFolder = <workspace>/_ai). Guidelines live at the
  // workspace root (sibling of _ai); roles/quests live under _ai.
  late Directory workspace;
  late Directory aiFolder;

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
    aiFolder: aiFolder,
    variables: variables,
    clock: () => clock,
    role: role,
    strict: strict,
    chatTranscript: chatTranscript,
    activeDocument: activeDocument,
  );

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('specs_compose_');
    aiFolder = Directory('${workspace.path}/_ai')..createSync();
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  group('built-in placeholders (tom_specs_editor_specification.md §11.5 '
      'P1)', () {
    test('quest resolves to the workspace name; date/time to the clock', () {
      final composer = make(role: 'Engineer');
      expect(
        composer.compose(r'${quest} on ${date} at ${time} as ${role}'),
        'tom_agent_container on 2026-06-17 at 09:05:03 as Engineer',
      );
    });

    test('builtInsFor flags every built-in as read-only', () {
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
    test('\${chat} resolves via the injected transcript provider', () {
      final composer = make(chatTranscript: () => 'User: hi\nAssistant: hello');
      expect(
        composer.compose(r'transcript:\n${chat}'),
        'transcript:\\nUser: hi\nAssistant: hello',
      );
    });

    test('\${file} resolves via the injected active-document provider', () {
      final composer = make(activeDocument: () => '# PD00\n\nbody');
      expect(composer.compose(r'doc:\n${file}'), 'doc:\\n# PD00\n\nbody');
    });

    test('chat/file render empty when no provider is bound (lenient)', () {
      final composer = make();
      expect(composer.compose(r'[${chat}][${file}]'), '[][]');
    });

    test('builtInsFor reflects the providers\' live values', () {
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
    test('a custom variable resolves via \${name} and the {{name}} alias', () {
      final composer = make(
        variables: const <ChatVariable>[
          ChatVariable(name: 'project', value: 'TomSpecs'),
        ],
      );
      expect(
        composer.compose(r'${project} / {{project}}'),
        'TomSpecs / TomSpecs',
      );
    });
  });

  group('file-injection against the _ai/ folder '
      '(tom_specs_editor_specification.md §11.5 P1)', () {
    test('\${file-<relpath>} injects the file contents from _ai/', () {
      File('${aiFolder.path}/notes/brief.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('the brief body');
      final composer = make();
      expect(
        composer.compose(r'context: ${file-notes/brief.md}'),
        'context: the brief body',
      );
    });

    test('a missing injected file renders empty in lenient mode', () {
      final composer = make();
      expect(composer.compose(r'a${file-missing.md}b'), 'ab');
    });
  });

  group('namespaced file-injection prefixes (tom_specs_editor_specification.md '
      '§11.5 P1, OE-13)', () {
    test('\${guidelines-<name>} reads _copilot_guidelines/<name>.md at the '
        'workspace root', () {
      File('${workspace.path}/_copilot_guidelines/coding.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('coding rules');
      final composer = make();
      expect(composer.compose(r'${guidelines-coding}'), 'coding rules');
    });

    test('\${guidelines-<name>} accepts an explicit .md and falls back to '
        '_guidelines/', () {
      File('${workspace.path}/_guidelines/index.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('the index');
      final composer = make();
      expect(composer.compose(r'${guidelines-index.md}'), 'the index');
    });

    test('\${role-<name>} reads _ai/roles/<name>.md (flat), then the folder '
        'layout', () {
      File('${aiFolder.path}/roles/reviewer/role.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('be critical');
      final composer = make();
      expect(composer.compose(r'${role-reviewer}'), 'be critical');
    });

    test('\${quest-<type>} reads the first _ai/quests/<quest>/<type>.<quest>.* '
        'match (quest = workspace name)', () {
      File(
        '${aiFolder.path}/quests/tom_agent_container/'
        'overview.tom_agent_container.md',
      ).createSync(recursive: true);
      File(
        '${aiFolder.path}/quests/tom_agent_container/'
        'overview.tom_agent_container.md',
      ).writeAsStringSync('quest overview body');
      final composer = make();
      expect(composer.compose(r'${quest-overview}'), 'quest overview body');
    });

    test('a missing namespaced injection renders empty in lenient mode', () {
      final composer = make();
      expect(
        composer.compose(r'[${guidelines-x}][${role-y}][${quest-z}]'),
        '[][][]',
      );
    });
  });

  group('expression form is disabled '
      '(tom_specs_editor_specification.md §11.5)', () {
    test('\${{ … }} yields the clear unsupported-error', () {
      final composer = make();
      expect(
        () => composer.compose(r'compute ${{ 1 + 1 }}'),
        throwsA(isA<PlaceholderExpressionsUnsupportedError>()),
      );
    });
  });
}
