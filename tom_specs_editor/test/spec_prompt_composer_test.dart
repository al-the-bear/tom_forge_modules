import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_specs_editor/src/agent/spec_prompt_composer.dart';

void main() {
  late Directory aiFolder;

  // A fixed clock so the `${date}` / `${time}` built-ins are deterministic.
  final clock = DateTime(2026, 6, 17, 9, 5, 3);

  SpecPromptComposer make({
    List<ChatVariable> variables = const <ChatVariable>[],
    String role = '',
    bool strict = false,
  }) =>
      SpecPromptComposer(
        workspaceName: 'tom_agent_container',
        aiFolder: aiFolder,
        variables: variables,
        clock: () => clock,
        role: role,
        strict: strict,
      );

  setUp(() => aiFolder = Directory.systemTemp.createTempSync('specs_compose_'));
  tearDown(() => aiFolder.deleteSync(recursive: true));

  group('built-in placeholders (§11.5 P1)', () {
    test('quest resolves to the workspace name; date/time to the clock', () {
      final composer = make(role: 'Engineer');
      expect(
        composer.compose(r'${quest} on ${date} at ${time} as ${role}'),
        'tom_agent_container on 2026-06-17 at 09:05:03 as Engineer',
      );
    });

    test('builtInsFor flags every built-in as read-only', () {
      final builtIns = make().builtInsFor(clock);
      expect(builtIns.map((v) => v.name),
          containsAll(<String>['date', 'time', 'quest', 'role']));
      expect(builtIns.every((v) => v.builtIn), isTrue);
    });
  });

  group('chat variables (§11.4) + alias', () {
    test('a custom variable resolves via \${name} and the {{name}} alias', () {
      final composer = make(variables: const <ChatVariable>[
        ChatVariable(name: 'project', value: 'TomSpecs'),
      ]);
      expect(composer.compose(r'${project} / {{project}}'),
          'TomSpecs / TomSpecs');
    });
  });

  group('file-injection against the _ai/ folder (§11.5 P1)', () {
    test('\${file-<relpath>} injects the file contents from _ai/', () {
      File('${aiFolder.path}/notes/brief.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('the brief body');
      final composer = make();
      expect(composer.compose(r'context: ${file-notes/brief.md}'),
          'context: the brief body');
    });

    test('a missing injected file renders empty in lenient mode', () {
      final composer = make();
      expect(composer.compose(r'a${file-missing.md}b'), 'ab');
    });
  });

  group('expression form is disabled (§11.5)', () {
    test('\${{ … }} yields the clear unsupported-error', () {
      final composer = make();
      expect(
        () => composer.compose(r'compute ${{ 1 + 1 }}'),
        throwsA(isA<PlaceholderExpressionsUnsupportedError>()),
      );
    });
  });
}
