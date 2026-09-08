// Tests for the editor's live Tom Brain profile binding (followup item 7): the
// SpecAgentProfile / SpecAgentProfiles that resolve an engine AgentContext into
// the running send config — the guidelines prompt (via the prompt registry),
// the MCP surface the toolset enables, and the scope profile — per the Q1
// mapping (F1). This replaces the static AgentContext placeholder.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_spec_engine/agent.dart';

import 'package:tom_specs_editor/src/agent/agent_tools_module.dart';
import 'package:tom_specs_editor/src/agent/spec_agent_profile.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A minimal class graph with one content section.
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
      ],
    },
  },
};

AgentToolsModule _module(Directory dir) {
  final model = SpecModel.fromJson(_sampleJson());
  final review = ReviewStore(File('${dir.path}/review.yaml'));
  return AgentToolsModule(
    modelFuture: Future<SpecModel>.value(model),
    review: review,
    scriptWorkspaceRoot: dir.path,
  );
}

/// A compose registry that returns a fixed prompt for the DocSpecs guidelines
/// token and empty for anything else, mirroring the lenient placeholder
/// composer without touching the filesystem.
String _composeWith(String guidelinesPrompt) => guidelinesPrompt;

void main() {
  late Directory dir;
  late AgentToolsModule module;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('specs_agent_profile_');
    module = _module(dir);
  });
  tearDown(() async {
    await module.memoryPlane.dispose();
    dir.deleteSync(recursive: true);
  });

  SpecAgentProfiles profiles({
    String guidelinesPrompt = 'DOCSPECS GUIDELINES',
  }) => SpecAgentProfiles(
    compose: (template) {
      // The composer is always invoked with a guidelines placeholder. The
      // DocSpecs token yields the configured prompt; the other applications'
      // guidelines docs are unauthored on disk → lenient-empty.
      expect(template, startsWith('\${guidelines-'));
      return template == '\${guidelines-$docSpecsGuidelinesName}'
          ? _composeWith(guidelinesPrompt)
          : '';
    },
    servers: module.servers,
    serverToolGroups: module.serverToolGroups,
  );

  test('the editor server→group map covers exactly the editor MCP servers', () {
    expect(module.serverToolGroups.keys.toSet(), module.servers.keys.toSet());
  });

  test('the DocSpecs profile binds the reference application context', () {
    final docSpecs = profiles().docSpecs;
    expect(docSpecs.application, docSpecsApplication);
    expect(docSpecs.toolset, {
      AgentToolGroup.doc,
      AgentToolGroup.memory,
      AgentToolGroup.file,
      AgentToolGroup.script,
    });
    expect(docSpecs.scopeNames, ['spec', 'files', 'memory']);
  });

  test(
    'the prompt registry resolves the guidelines doc into the system prompt',
    () {
      final docSpecs = profiles().docSpecs;
      expect(docSpecs.systemPrompt, 'DOCSPECS GUIDELINES');
    },
  );

  test('all four tool groups select both editor MCP servers', () {
    final docSpecs = profiles().docSpecs;
    expect(docSpecs.mcpServers.keys.toSet(), module.servers.keys.toSet());
  });

  test('buildSendConfig carries the additive prompt and the MCP surface', () {
    final config = profiles().docSpecs.buildSendConfig();
    expect(config.systemPrompt, 'DOCSPECS GUIDELINES');
    expect(config.mcpServers, isNotNull);
    expect(config.mcpServers!.keys.toSet(), module.servers.keys.toSet());
  });

  test('an empty guidelines doc sends no additive prompt', () {
    final config = profiles(guidelinesPrompt: '').docSpecs.buildSendConfig();
    expect(config.systemPrompt, isNull);
  });

  test(
    'the memory scope addresses application/session/document (Q1 mapping)',
    () {
      final scope = profiles().docSpecs.memoryScope(
        session: 'phase-3',
        document: 'pd00',
      );
      expect(scope.application, docSpecsApplication);
      expect(scope.session, 'phase-3');
      expect(scope.document, 'pd00');
    },
  );

  test('all three canonical applications are authored with their own context '
      '(item 10)', () {
    final resolver = profiles();
    expect(resolver.isAuthored(docSpecsApplication), isTrue);
    expect(resolver.isAuthored(codeSpecsApplication), isTrue);
    expect(resolver.isAuthored(implementationApplication), isTrue);
    expect(resolver.authoredApplications.toSet(), tomSpecsApplications.toSet());

    // CodeSpecs binds its own application + the full surface, not the fallback.
    final codeSpecs = resolver.profileFor(codeSpecsApplication);
    expect(codeSpecs.application, codeSpecsApplication);
    expect(codeSpecs.toolset, {
      AgentToolGroup.doc,
      AgentToolGroup.memory,
      AgentToolGroup.file,
      AgentToolGroup.script,
    });
    expect(codeSpecs.scopeNames, ['spec', 'files', 'memory']);
    expect(codeSpecs.mcpServers.keys.toSet(), module.servers.keys.toSet());

    final implementation = resolver.profileFor(implementationApplication);
    expect(implementation.application, implementationApplication);
  });

  test('a non-canonical application falls back to the DocSpecs profile', () {
    final resolver = profiles();
    expect(resolver.isAuthored('nope'), isFalse);
    final fallback = resolver.profileFor('nope');
    expect(fallback.application, docSpecsApplication);
  });
}
