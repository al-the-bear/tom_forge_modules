import 'package:flutter/material.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';

import 'config_editors.dart';
import 'config_field.dart';
import 'editor_preferences.dart';

/// Builds the declarative [ConfigListSpec]/[ConfigObjectSpec]s for the seven
/// config editors (`tom_specs_editor_specification.md` §12). Each spec binds a
/// `tom_core_agentic` store to a detail form; the generic editors render them.
/// Models are immutable value types with `toYaml`/`fromYaml` but no `copyWith`,
/// so each field setter edits through a `fromYaml(toYaml()..[key] = value)`
/// round-trip — the same pattern the step-16 queue controller uses.
class SpecsConfigSpecs {
  SpecsConfigSpecs({
    AgentProfileStore? profiles,
    PromptTemplateStore? promptTemplates,
    QueueTemplateStore? queueTemplates,
    ChatVariableStore? chatVariables,
    TimedRequestStore? timedRequests,
    PromptQueueStore? queue,
    AgentSettingsStore? agentSettings,
    EditorPreferencesStore? preferences,
    this.compose,
  })  : profiles = profiles ?? AgentProfileStore.resolveDefault(),
        promptTemplates =
            promptTemplates ?? PromptTemplateStore.resolveDefault(),
        queueTemplates = queueTemplates ?? QueueTemplateStore.resolveDefault(),
        chatVariables = chatVariables ?? ChatVariableStore.resolveDefault(),
        timedRequests = timedRequests ?? TimedRequestStore.resolveDefault(),
        queue = queue ?? PromptQueueStore.resolveDefault(),
        agentSettings = agentSettings ?? AgentSettingsStore.resolveDefault(),
        preferences = preferences ?? EditorPreferencesStore.resolveDefault();

  final AgentProfileStore profiles;
  final PromptTemplateStore promptTemplates;
  final QueueTemplateStore queueTemplates;
  final ChatVariableStore chatVariables;
  final TimedRequestStore timedRequests;
  final PromptQueueStore queue;
  final AgentSettingsStore agentSettings;
  final EditorPreferencesStore preferences;

  /// Expands a placeholder-bearing string for the
  /// `tom_specs_editor_specification.md` §12 live placeholder preview (OE-14) —
  /// typically `SpecPromptComposer.compose`. When null, the preview field is
  /// omitted (the editors stay usable without a wired composer, e.g. in unit
  /// tests).
  final String Function(String source)? compose;

  static String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  Uri _uri(String path) => Uri(scheme: 'specs-config', host: 'config', path: path);

  // ── Prompt Queue ───────────────────────────────────────────────────────────

  ConfigListSpec<QueuedPrompt> queueSpec() => ConfigListSpec<QueuedPrompt>(
        title: 'Prompt Queue',
        icon: Icons.playlist_play_outlined,
        uri: _uri('/queue'),
        backingFile: queue.file,
        load: queue.load,
        save: queue.save,
        labelOf: (p) =>
            p.originalText.isEmpty ? '(empty prompt)' : p.originalText,
        createNew: () => QueuedPrompt(
          id: _newId('q'),
          originalText: '',
          expandedText: '',
          createdAt: _nowIso(),
        ),
        fields: [
          ConfigField.text(
            label: 'Prompt',
            multiline: true,
            required: true,
            help: 'The text sent to the agent. Placeholders are expanded when '
                'the item is dispatched.',
            get: (p) => p.originalText,
            set: (p, t) => QueuedPrompt.fromYaml(
              p.toYaml()
                ..['originalText'] = t
                ..['expandedText'] = t,
            ),
          ),
          ConfigField.enumeration<QueuedPrompt, QueuedPromptStatus>(
            label: 'Status',
            values: QueuedPromptStatus.values,
            labelOf: (s) => s.value,
            help: 'Lifecycle state — pending items are sent in order; '
                'sent/failed items are kept for history.',
            get: (p) => p.status,
            set: (p, s) =>
                QueuedPrompt.fromYaml(p.toYaml()..['status'] = s.value),
          ),
        ],
      );

  // ── Queue Templates ────────────────────────────────────────────────────────

  ConfigListSpec<QueueTemplate> queueTemplateSpec() =>
      ConfigListSpec<QueueTemplate>(
        title: 'Queue Templates',
        icon: Icons.bookmark_outline,
        uri: _uri('/queue-templates'),
        backingFile: queueTemplates.file,
        load: queueTemplates.load,
        save: queueTemplates.save,
        labelOf: (t) => t.name.isEmpty ? '(unnamed)' : t.name,
        createNew: () => QueueTemplate(id: _newId('qt'), name: 'New template'),
        fields: [
          ConfigField.text(
            label: 'Name',
            required: true,
            help: "Identifies the template in the queue's load-template picker.",
            get: (t) => t.name,
            set: (t, v) =>
                QueueTemplate.fromYaml(t.toYaml()..['name'] = v),
          ),
          ConfigField.text(
            label: 'Prompts (one per line)',
            multiline: true,
            help: 'One prompt per line; blank lines are ignored. Loading the '
                'template enqueues each line as a separate prompt.',
            get: (t) => t.prompts.join('\n'),
            set: (t, v) => QueueTemplate.fromYaml(
              t.toYaml()
                ..['prompts'] = [
                  for (final line in v.split('\n'))
                    if (line.trim().isNotEmpty) line,
                ],
            ),
          ),
        ],
      );

  // ── Profiles ───────────────────────────────────────────────────────────────

  ConfigListSpec<AgentProfile> profileSpec() => ConfigListSpec<AgentProfile>(
        title: 'Profiles',
        icon: Icons.account_circle_outlined,
        uri: _uri('/profiles'),
        backingFile: profiles.file,
        load: profiles.load,
        save: profiles.save,
        labelOf: (p) => p.name.isEmpty ? '(unnamed)' : p.name,
        createNew: () => AgentProfile(id: _newId('p'), name: 'New profile'),
        fields: [
          ConfigField.text(
            label: 'Name',
            required: true,
            help: "Shown in the composer's profile picker.",
            get: (p) => p.name,
            set: (p, v) => AgentProfile.fromYaml(p.toYaml()..['name'] = v),
          ),
          ConfigField.text(
            label: 'Description',
            help: 'Optional note about when to use this profile. Not sent to '
                'the agent.',
            get: (p) => p.description,
            set: (p, v) =>
                AgentProfile.fromYaml(p.toYaml()..['description'] = v),
          ),
          ConfigField.text(
            label: 'System prompt',
            multiline: true,
            help: 'Prepended to every turn while this profile is active. '
                r'Supports ${…} placeholders.',
            get: (p) => p.systemPrompt,
            set: (p, v) =>
                AgentProfile.fromYaml(p.toYaml()..['systemPrompt'] = v),
          ),
          // `tom_specs_editor_specification.md` §12 "live placeholder preview"
          // — only when a composer is wired.
          if (compose != null)
            ConfigField.placeholderPreview(
              label: 'System prompt preview',
              help: 'How the system prompt resolves with placeholders expanded.',
              get: (p) => p.systemPrompt,
              compose: compose!,
            ),
          ConfigField.integer(
            label: 'Max tokens',
            positive: true,
            help: 'Caps the response length for this profile. Leave empty to '
                'use the agent default.',
            get: (p) => p.maxTokens,
            set: (p, n) =>
                AgentProfile.fromYaml(p.toYaml()..['maxTokens'] = n),
          ),
          ConfigField.boolean(
            label: 'Thinking enabled',
            help: 'Lets the model use extended thinking before replying, when '
                'the model supports it.',
            get: (p) => p.thinkingEnabled ?? false,
            set: (p, b) =>
                AgentProfile.fromYaml(p.toYaml()..['thinkingEnabled'] = b),
          ),
          ConfigField.text(
            label: 'Interrupt retry prefix',
            multiline: true,
            help: 'Text prepended to the follow-up when a turn is interrupted '
                'and retried.',
            get: (p) => p.interruptRetryPrefix,
            set: (p, v) => AgentProfile.fromYaml(
                p.toYaml()..['interruptRetryPrefix'] = v),
          ),
          ConfigField.boolean(
            label: 'Default profile',
            help: 'Selected automatically when the editor opens. Only one '
                'profile should be the default.',
            get: (p) => p.isDefault ?? false,
            set: (p, b) => AgentProfile.fromYaml(p.toYaml()..['isDefault'] = b),
          ),
        ],
      );

  // ── Prompt Templates ───────────────────────────────────────────────────────

  ConfigListSpec<PromptTemplate> promptTemplateSpec() =>
      ConfigListSpec<PromptTemplate>(
        title: 'Prompt Templates',
        icon: Icons.notes_outlined,
        uri: _uri('/prompt-templates'),
        backingFile: promptTemplates.file,
        load: promptTemplates.load,
        save: promptTemplates.save,
        labelOf: (t) => t.name.isEmpty ? '(unnamed)' : t.name,
        createNew: () =>
            PromptTemplate(id: _newId('pt'), name: 'New template'),
        fields: [
          ConfigField.text(
            label: 'Name',
            required: true,
            help: 'Shown in the prompt-template picker.',
            get: (t) => t.name,
            set: (t, v) =>
                PromptTemplate.fromYaml(t.toYaml()..['name'] = v),
          ),
          ConfigField.text(
            label: 'Body',
            multiline: true,
            help: r'Template text. Supports ${…} placeholders, expanded live '
                'in the preview below.',
            get: (t) => t.body,
            set: (t, v) =>
                PromptTemplate.fromYaml(t.toYaml()..['body'] = v),
          ),
          // `tom_specs_editor_specification.md` §12 "live placeholder preview"
          // — only when a composer is wired.
          if (compose != null)
            ConfigField.placeholderPreview(
              label: 'Preview',
              help: 'How the body resolves with placeholders expanded.',
              get: (t) => t.body,
              compose: compose!,
            ),
          ConfigField.boolean(
            label: 'Seeds the user-message field',
            help: "When on, choosing this template fills the composer's "
                'user-message field instead of sending immediately.',
            get: (t) => t.isUserMessage,
            set: (t, b) =>
                PromptTemplate.fromYaml(t.toYaml()..['isUserMessage'] = b),
          ),
        ],
      );

  // ── Chat Variables ─────────────────────────────────────────────────────────

  ConfigListSpec<ChatVariable> chatVariableSpec() =>
      ConfigListSpec<ChatVariable>(
        title: 'Chat Variables',
        icon: Icons.data_object_outlined,
        uri: _uri('/chat-variables'),
        backingFile: chatVariables.file,
        load: chatVariables.load,
        save: chatVariables.save,
        labelOf: (v) => v.name.isEmpty ? '(unnamed)' : v.name,
        isReadOnly: (v) => v.builtIn,
        createNew: () => const ChatVariable(name: 'newVar'),
        fields: [
          ConfigField.text(
            label: 'Name',
            required: true,
            help: r'Referenced as ${name} inside prompts and templates. '
                'Built-in variables are read-only.',
            get: (v) => v.name,
            set: (v, t) => ChatVariable.fromYaml(v.toYaml()..['name'] = t),
          ),
          ConfigField.text(
            label: 'Value',
            multiline: true,
            help: r'The text ${name} expands to.',
            get: (v) => v.value,
            set: (v, t) => ChatVariable.fromYaml(v.toYaml()..['value'] = t),
          ),
          ConfigField.text(
            label: 'Description',
            help: 'Optional note about the variable. Not expanded.',
            get: (v) => v.description,
            set: (v, t) =>
                ChatVariable.fromYaml(v.toYaml()..['description'] = t),
          ),
        ],
      );

  // ── Timed Requests ─────────────────────────────────────────────────────────

  ConfigListSpec<TimedRequest> timedRequestSpec() =>
      ConfigListSpec<TimedRequest>(
        title: 'Timed Requests',
        icon: Icons.schedule_outlined,
        uri: _uri('/timed-requests'),
        backingFile: timedRequests.file,
        load: timedRequests.load,
        save: timedRequests.save,
        labelOf: (r) =>
            r.originalText.isEmpty ? '(empty request)' : r.originalText,
        createNew: () => TimedRequest(
          id: _newId('tr'),
          originalText: '',
          scheduleMode: ScheduleMode.interval,
          intervalMinutes: 60,
        ),
        fields: [
          ConfigField.text(
            label: 'Prompt',
            multiline: true,
            required: true,
            help: 'The request text sent automatically on the schedule.',
            get: (r) => r.originalText,
            set: (r, t) =>
                TimedRequest.fromYaml(r.toYaml()..['originalText'] = t),
          ),
          ConfigField.boolean(
            label: 'Enabled',
            help: 'When off, the schedule is kept but no requests fire.',
            get: (r) => r.enabled,
            set: (r, b) => TimedRequest.fromYaml(r.toYaml()..['enabled'] = b),
          ),
          ConfigField.enumeration<TimedRequest, ScheduleMode>(
            label: 'Schedule mode',
            values: ScheduleMode.values,
            labelOf: (m) => m.value,
            help: 'How the interval is interpreted (e.g. a fixed interval vs. '
                'a time of day).',
            get: (r) => r.scheduleMode,
            set: (r, m) =>
                TimedRequest.fromYaml(r.toYaml()..['scheduleMode'] = m.value),
          ),
          ConfigField.integer(
            label: 'Interval (minutes)',
            positive: true,
            help: 'Minutes between automatic sends.',
            get: (r) => r.intervalMinutes,
            set: (r, n) =>
                TimedRequest.fromYaml(r.toYaml()..['intervalMinutes'] = n),
          ),
        ],
      );

  // ── Agent Settings (singleton) ─────────────────────────────────────────────

  ConfigObjectSpec<AgentSettings> agentSettingsSpec() =>
      ConfigObjectSpec<AgentSettings>(
        title: 'Agent Settings',
        icon: Icons.tune_outlined,
        uri: _uri('/agent-settings'),
        backingFile: agentSettings.file,
        load: agentSettings.load,
        save: agentSettings.save,
        fields: [
          ConfigField.text(
            label: 'Bridge host',
            required: true,
            help: 'Host the editor connects to for the VS Code bridge.',
            get: (s) => s.bridgeHost,
            set: (s, v) => s.copyWith(bridgeHost: v),
          ),
          ConfigField.integer(
            label: 'Port scan start',
            positive: true,
            help: 'First port tried when discovering the bridge.',
            get: (s) => s.portScanStart,
            set: (s, n) => s.copyWith(portScanStart: n ?? s.portScanStart),
          ),
          ConfigField.integer(
            label: 'Port scan end',
            positive: true,
            help: 'Last port tried. Must be >= the start port.',
            get: (s) => s.portScanEnd,
            set: (s, n) => s.copyWith(portScanEnd: n ?? s.portScanEnd),
            validate: (s) => s.hasValidPortRange
                ? null
                : 'Port scan end must be >= port scan start',
          ),
          ConfigField.integer(
            label: 'Default max tokens',
            positive: true,
            help: 'Response-length cap used when a profile does not set its '
                'own.',
            get: (s) => s.maxTokens,
            set: (s, n) => AgentSettings(
              bridgeHost: s.bridgeHost,
              portScanStart: s.portScanStart,
              portScanEnd: s.portScanEnd,
              defaultProfileId: s.defaultProfileId,
              maxTokens: n,
              maxRounds: s.maxRounds,
              thinkingEnabled: s.thinkingEnabled,
              promptCachingEnabled: s.promptCachingEnabled,
              toolApprovalMode: s.toolApprovalMode,
            ),
          ),
          ConfigField.boolean(
            label: 'Thinking enabled (default)',
            help: 'Default extended-thinking setting for profiles that do not '
                'override it.',
            get: (s) => s.thinkingEnabled ?? false,
            set: (s, b) => s.copyWith(thinkingEnabled: b),
          ),
          ConfigField.boolean(
            label: 'Prompt caching (default)',
            help: 'Enables Anthropic prompt caching to reduce repeated-context '
                'cost.',
            get: (s) => s.promptCachingEnabled ?? false,
            set: (s, b) => s.copyWith(promptCachingEnabled: b),
          ),
        ],
      );
}
