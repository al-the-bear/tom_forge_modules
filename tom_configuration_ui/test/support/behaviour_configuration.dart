// A configuration description of the kinds with behaviour (fonts, keys, a
// key binding table, a tool path, an action, a flow, a status, run-time
// choices, scaled numbers, dates and times, a colour, groups) and the hooks
// a test application supplies for them.

import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:tom_forge_core/tom_forge_core.dart';

const fontSetting = ForgeFontFamilySetting(
  id: 'codeFont',
  storage: ForgeSettingStorage('demo.codeFont'),
  label: ForgeText('demo.codeFont', 'Code font'),
  monospace: true,
  suggestions: ['JetBrains Mono'],
);

const quickOpenSetting = ForgeKeyBindingSetting(
  id: 'quickOpen',
  storage: ForgeSettingStorage('demo.quickOpen'),
  label: ForgeText('demo.quickOpen', 'Quick open'),
);

const chordSetting = ForgeKeyChordSetting(
  id: 'chord',
  storage: ForgeSettingStorage('demo.chord'),
  label: ForgeText('demo.chord', 'Save all'),
  maxStrokes: 3,
);

const deletedSetting = ForgeStringListSetting(
  id: 'deletedBindings',
  storage: ForgeSettingStorage('demo.deletedBindings'),
  label: ForgeText('demo.deletedBindings', 'Deleted bindings'),
);

const shortcutsSetting = ForgeKeyBindingTableSetting(
  id: 'shortcuts',
  storage: ForgeSettingStorage('demo.shortcuts'),
  label: ForgeText('demo.shortcuts', 'Shortcuts'),
  catalogue: 'demo.actions',
  deletedBindings: deletedSetting,
  wildcardPrefixes: ['md'],
);

const toolSetting = ForgeToolPathSetting(
  id: 'tool',
  storage: ForgeSettingStorage('demo.tool'),
  label: ForgeText('demo.tool', 'Pandoc'),
  detector: 'demo.detector',
  hints: ForgeDetectionHints(executableNames: ['pandoc']),
  hint: ForgeText('demo.tool.hint', 'Found automatically'),
  helpPanel: 'demo.installHelp',
  actions: ['demo.download'],
);

const reloadSetting = ForgeActionSetting(
  id: 'reload',
  label: ForgeText('demo.reload', 'Configuration file'),
  action: 'demo.reload',
);

const signInSetting = ForgeActionSetting(
  id: 'signIn',
  label: ForgeText('demo.signIn', 'Account'),
  flow: 'demo.signIn',
);

const healthSetting = ForgeStatusSetting(
  id: 'health',
  label: ForgeText('demo.health', 'Index'),
  status: 'demo.health',
  maxItems: 2,
);

const openerSetting = ForgeChoiceSetting(
  id: 'opener',
  storage: ForgeSettingStorage('demo.opener'),
  label: ForgeText('demo.opener', 'Open with'),
  defaultValue: '',
  choicesProvider: 'demo.editors',
  allowNone: true,
);

const openersSetting = ForgeStringMapSetting(
  id: 'openers',
  storage: ForgeSettingStorage('demo.openers'),
  label: ForgeText('demo.openers', 'File types'),
  defaultValue: {'*': 'text', '.md': 'md'},
  valueChoicesProvider: 'demo.editors',
  keyNormalizer: ForgeMapKeyNormalizer.fileExtension,
  defaultKey: '*',
  defaultKeyLabel: ForgeText('demo.openers.other', 'Every other file'),
  allowEmptyValues: true,
);

const limitSetting = ForgeIntSetting(
  id: 'limit',
  storage: ForgeSettingStorage('demo.limit'),
  label: ForgeText('demo.limit', 'Size limit'),
  defaultValue: 5 * 1048576,
  scale: 1048576,
  unit: ForgeText('demo.limit.unit', 'MB'),
);

const sinceSetting = ForgeDateSetting(
  id: 'since',
  storage: ForgeSettingStorage('demo.since'),
  label: ForgeText('demo.since', 'Since'),
  defaultValue: ForgeDate(2026, 11, 10),
);

const quietSetting = ForgeTimeSetting(
  id: 'quiet',
  storage: ForgeSettingStorage('demo.quiet'),
  label: ForgeText('demo.quiet', 'Quiet from'),
  defaultValue: ForgeTimeOfDay(22, 0),
);

const untilSetting = ForgeDateTimeSetting(
  id: 'until',
  storage: ForgeSettingStorage('demo.until'),
  label: ForgeText('demo.until', 'Until'),
  defaultValue: ForgeDateTime(ForgeDate(2026, 11, 10), ForgeTimeOfDay(8, 0)),
);

const highlightSetting = ForgeColorSetting(
  id: 'highlight',
  storage: ForgeSettingStorage('demo.highlight'),
  label: ForgeText('demo.highlight', 'Highlight'),
  defaultValue: 0xFFFF0000,
);

const keysGroup = ForgeSettingsGroup(
  id: 'keys',
  title: ForgeText('demo.keys', 'Keyboard'),
  help: ForgeText('demo.keys.help', 'Single keys and chords.'),
  settings: [quickOpenSetting, chordSetting],
);

const timesGroup = ForgeSettingsGroup(
  id: 'times',
  title: ForgeText('demo.times', 'Times'),
  collapsed: true,
  settings: [quietSetting, untilSetting],
);

const appearanceSection = ForgeSettingsSection(
  id: 'appearance',
  title: ForgeText('demo.appearance', 'Appearance'),
  order: 10,
  settings: [
    fontSetting,
    highlightSetting,
    limitSetting,
    sinceSetting,
    keysGroup,
    timesGroup,
  ],
);

const toolsSection = ForgeSettingsSection(
  id: 'tools',
  title: ForgeText('demo.tools', 'Tools'),
  order: 20,
  settings: [
    toolSetting,
    reloadSetting,
    signInSetting,
    healthSetting,
    openerSetting,
    openersSetting,
  ],
);

const shortcutsSection = ForgeSettingsSection(
  id: 'shortcuts',
  title: ForgeText('demo.shortcutsSection', 'Keyboard shortcuts'),
  order: 30,
  settings: [shortcutsSetting],
);

const behaviourDescription = ForgeConfigurationDescription(
  id: 'behaviour',
  title: ForgeText('behaviour', 'Behaviour'),
  sections: [appearanceSection, toolsSection, shortcutsSection],
);

ForgeKeyChord _key(LogicalKeyboardKey key, {bool shift = false}) =>
    ForgeKeyChord.single(
      ForgeKeyStroke(key.keyId, primaryModifier: true, shift: shift),
    );

/// The hooks of [behaviourDescription], with handles a test drives: the
/// action's and the choices' completers, the status stream, what ran.
class BehaviourHooks {
  BehaviourHooks() {
    hooks = ForgeSettingHooks(
      choices: [
        ForgeCallbackChoicesProvider(
          id: ForgeFontFamilySetting.systemFonts,
          onChoices: (context) async {
            fontKeys.add(context.key);
            final mono = [
              const ForgeSettingChoice(
                'Fira Code',
                ForgeText.literal('Fira Code'),
              ),
              const ForgeSettingChoice('Menlo', ForgeText.literal('Menlo')),
            ];
            return context.key == 'monospace'
                ? mono
                : [
                    ...mono,
                    const ForgeSettingChoice(
                      'Arial',
                      ForgeText.literal('Arial'),
                    ),
                  ];
          },
        ),
        ForgeCallbackChoicesProvider(
          id: 'demo.editors',
          onChoices: (context) async {
            editorKeys.add(context.key);
            final pending = editorsAnswer;
            if (pending != null) await pending.future;
            return const [
              ForgeSettingChoice(
                'md',
                ForgeText('demo.editors.md', 'Markdown'),
              ),
              ForgeSettingChoice('text', ForgeText.literal('Plain text')),
            ];
          },
        ),
      ],
      catalogues: [
        ForgeCallbackActionCatalogue(
          id: 'demo.actions',
          onActions: (context) async => [
            ForgeCatalogueAction(
              id: 'md.bold',
              label: 'Bold',
              scope: 'markdown',
              group: 'Markdown',
              defaultBinding: _key(LogicalKeyboardKey.keyB),
            ),
            ForgeCatalogueAction(
              id: 'md.italic',
              label: 'Italic',
              scope: 'markdown',
              group: 'Markdown',
              defaultBinding: _key(LogicalKeyboardKey.keyI),
            ),
            ForgeCatalogueAction(
              id: 'app.save',
              label: 'Save',
              group: 'Application',
              defaultBinding: _key(LogicalKeyboardKey.keyS),
            ),
            ForgeCatalogueAction(
              id: 'app.find',
              label: 'Find',
              group: 'Application',
              defaultBinding: _key(LogicalKeyboardKey.keyF),
            ),
          ],
        ),
      ],
      detectors: [
        ForgeCallbackDetector(
          id: 'demo.detector',
          onCheck: (context, value, hints) async {
            if (value.isEmpty) {
              return const ForgeDetectedCandidate(
                value: '/usr/local/bin/pandoc',
                level: ForgeStatusLevel.ok,
                version: '3.1',
                source: 'PATH',
              );
            }
            if (value == '/opt/pandoc/bin/pandoc') {
              return ForgeDetectedCandidate(
                value: value,
                level: ForgeStatusLevel.ok,
                version: '3.5',
              );
            }
            return ForgeDetectedCandidate(
              value: value,
              level: ForgeStatusLevel.error,
              reason: 'no such file',
            );
          },
          onDetect: (context, hints) async {
            detectHints = hints;
            context.progress(
              fraction: 0.5,
              message: const ForgeText(
                'demo.detect.progress',
                'Looking in PATH',
              ),
            );
            final gate = detectGate;
            if (gate != null) await gate.future;
            return const [
              ForgeDetectedCandidate(
                value: '/opt/pandoc/bin/pandoc',
                level: ForgeStatusLevel.ok,
                version: '3.5',
                source: 'search root',
              ),
              ForgeDetectedCandidate(
                value: '/usr/bin/pandoc',
                level: ForgeStatusLevel.warning,
                version: '1.9',
                reason: 'too old',
              ),
            ];
          },
        ),
      ],
      actions: [
        ForgeCallbackAction(
          id: 'demo.reload',
          label: const ForgeText('demo.reload.button', 'Reload'),
          emphasis: ForgeActionEmphasis.primary,
          onRun: (context) async {
            context.progress(
              fraction: 0.25,
              message: const ForgeText('demo.reload.progress', 'Reading files'),
            );
            final gate = reloadGate;
            if (gate != null) await gate.future;
            if (context.isCancelled) return const ForgeActionResult.cancelled();
            reloads++;
            return const ForgeActionResult.success(
              message: ForgeText('demo.reload.done', 'Reloaded 3 files.'),
              refresh: true,
            );
          },
        ),
        ForgeCallbackAction(
          id: 'demo.download',
          label: const ForgeText('demo.download', 'Download'),
          onRun: (context) async => const ForgeActionResult.failure(
            ForgeText('demo.download.failed', 'No network.'),
          ),
        ),
      ],
      statuses: [
        ForgeCallbackStatusProvider(
          id: 'demo.health',
          onCurrent: (context) async {
            statusReads++;
            return const ForgeStatusInfo(
              level: ForgeStatusLevel.warning,
              message: ForgeText('demo.health.stale', 'Index is stale'),
              detail: '12 files changed',
              items: [
                ForgeStatusItem(level: ForgeStatusLevel.error, text: 'a.md'),
                ForgeStatusItem(level: ForgeStatusLevel.error, text: 'b.md'),
                ForgeStatusItem(level: ForgeStatusLevel.error, text: 'c.md'),
              ],
            );
          },
          onWatch: (context) => statusStream.stream,
        ),
      ],
      flows: [_SignInFlow(this)],
    );
  }

  late final ForgeSettingHooks hooks;

  /// The status the provider streams.
  final StreamController<ForgeStatusInfo> statusStream =
      StreamController.broadcast();

  /// While set, the reload action waits for it.
  Completer<void>? reloadGate;

  /// While set, the detector's search waits for it.
  Completer<void>? detectGate;

  /// While set, the editors provider waits for it.
  Completer<void>? editorsAnswer;

  /// The keys the editors provider was asked with.
  final List<String?> editorKeys = [];

  /// The keys the font provider was asked with.
  final List<String?> fontKeys = [];

  ForgeDetectionHints? detectHints;
  int reloads = 0;
  int statusReads = 0;

  /// The one-time codes the flow was answered.
  final List<String> codes = [];

  Future<void> dispose() => statusStream.close();
}

/// A sign-in: a code to copy, then a one-time code (`123456` is right), then
/// done with the account name as the result's message.
class _SignInFlow extends ForgeSettingFlow {
  const _SignInFlow(this.owner);

  final BehaviourHooks owner;

  @override
  String get id => 'demo.signIn';

  @override
  ForgeText get label => const ForgeText('demo.signIn.button', 'Sign in');

  @override
  ForgeFlowSession start(ForgeSettingContext context) => _SignInSession(owner);
}

class _SignInSession implements ForgeFlowSession {
  _SignInSession(this.owner);

  final BehaviourHooks owner;
  int _step = 0;

  static const _input = ForgeFlowStep.input(
    title: ForgeText('demo.signIn.codeTitle', 'Enter the code'),
    fields: [
      ForgeFlowField(
        id: 'otp',
        label: ForgeText('demo.signIn.otp', 'One-time code'),
        kind: ForgeFlowFieldKind.oneTimeCode,
        length: 6,
      ),
    ],
  );

  @override
  Future<ForgeFlowStep> start() async => const ForgeFlowStep.show(
    title: ForgeText('demo.signIn.title', 'Sign in to Demo'),
    message: ForgeText('demo.signIn.message', 'Open the page and enter:'),
    url: 'https://example.invalid/device',
    code: 'WDJB-MJHT',
  );

  @override
  Future<ForgeFlowStep> respond(ForgeFlowResponse response) async {
    _step++;
    if (_step == 1) return _input;
    final code = response.values['otp'] ?? '';
    owner.codes.add(code);
    if (code != '123456') {
      return const ForgeFlowStep.input(
        title: ForgeText('demo.signIn.codeTitle', 'Enter the code'),
        fields: [
          ForgeFlowField(
            id: 'otp',
            label: ForgeText('demo.signIn.otp', 'One-time code'),
            kind: ForgeFlowFieldKind.oneTimeCode,
            length: 6,
          ),
        ],
        error: ForgeText('demo.signIn.wrong', 'That code is not right.'),
      );
    }
    return const ForgeFlowStep.done(
      ForgeActionResult.success(
        message: ForgeText('demo.signIn.done', 'Signed in as al.'),
      ),
    );
  }

  @override
  Future<ForgeFlowStep> poll() async => _input;

  @override
  void cancel() {}
}
