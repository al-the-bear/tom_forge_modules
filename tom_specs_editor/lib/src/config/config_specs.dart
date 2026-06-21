import 'package:flutter/material.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';

import 'config_editors.dart';
import 'config_field.dart';
import 'editor_preferences.dart';

/// Builds the declarative [ConfigListSpec]/[ConfigObjectSpec]s for the seven
/// config editors (§12). Each spec binds a `tom_core_agentic` store to a
/// detail form; the generic editors render them. Models are immutable value
/// types with `toYaml`/`fromYaml` but no `copyWith`, so each field setter edits
/// through a `fromYaml(toYaml()..[key] = value)` round-trip — the same pattern
/// the step-16 queue controller uses.
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

  /// Expands a placeholder-bearing string for the §12 live placeholder preview
  /// (OE-14) — typically `SpecPromptComposer.compose`. When null, the preview
  /// field is omitted (the editors stay usable without a wired composer, e.g.
  /// in unit tests).
  final String Function(String source)? compose;

  static String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  Uri _uri(String path) => Uri(scheme: 'specs-config', host: 'config', path: path);

  // ── Prompt Queue ──────────────────────────────────────────────────────────

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
            get: (p) => p.status,
            set: (p, s) =>
                QueuedPrompt.fromYaml(p.toYaml()..['status'] = s.value),
          ),
        ],
      );

  // ── Queue Templates ─────────────────────────────────────────────────────────

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
            get: (t) => t.name,
            set: (t, v) =>
                QueueTemplate.fromYaml(t.toYaml()..['name'] = v),
          ),
          ConfigField.text(
            label: 'Prompts (one per line)',
            multiline: true,
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
            get: (p) => p.name,
            set: (p, v) => AgentProfile.fromYaml(p.toYaml()..['name'] = v),
          ),
          ConfigField.text(
            label: 'Description',
            get: (p) => p.description,
            set: (p, v) =>
                AgentProfile.fromYaml(p.toYaml()..['description'] = v),
          ),
          ConfigField.text(
            label: 'System prompt',
            multiline: true,
            get: (p) => p.systemPrompt,
            set: (p, v) =>
                AgentProfile.fromYaml(p.toYaml()..['systemPrompt'] = v),
          ),
          // §12 "live placeholder preview" — only when a composer is wired.
          if (compose != null)
            ConfigField.placeholderPreview(
              label: 'System prompt preview',
              get: (p) => p.systemPrompt,
              compose: compose!,
            ),
          ConfigField.integer(
            label: 'Max tokens',
            positive: true,
            get: (p) => p.maxTokens,
            set: (p, n) =>
                AgentProfile.fromYaml(p.toYaml()..['maxTokens'] = n),
          ),
          ConfigField.boolean(
            label: 'Thinking enabled',
            get: (p) => p.thinkingEnabled ?? false,
            set: (p, b) =>
                AgentProfile.fromYaml(p.toYaml()..['thinkingEnabled'] = b),
          ),
          ConfigField.text(
            label: 'Interrupt retry prefix',
            multiline: true,
            get: (p) => p.interruptRetryPrefix,
            set: (p, v) => AgentProfile.fromYaml(
                p.toYaml()..['interruptRetryPrefix'] = v),
          ),
          ConfigField.boolean(
            label: 'Default profile',
            get: (p) => p.isDefault ?? false,
            set: (p, b) => AgentProfile.fromYaml(p.toYaml()..['isDefault'] = b),
          ),
        ],
      );

  // ── Prompt Templates ─────────────────────────────────────────────────────────

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
            get: (t) => t.name,
            set: (t, v) =>
                PromptTemplate.fromYaml(t.toYaml()..['name'] = v),
          ),
          ConfigField.text(
            label: 'Body',
            multiline: true,
            get: (t) => t.body,
            set: (t, v) =>
                PromptTemplate.fromYaml(t.toYaml()..['body'] = v),
          ),
          // §12 "live placeholder preview" — only when a composer is wired.
          if (compose != null)
            ConfigField.placeholderPreview(
              label: 'Preview',
              get: (t) => t.body,
              compose: compose!,
            ),
          ConfigField.boolean(
            label: 'Seeds the user-message field',
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
            get: (v) => v.name,
            set: (v, t) => ChatVariable.fromYaml(v.toYaml()..['name'] = t),
          ),
          ConfigField.text(
            label: 'Value',
            multiline: true,
            get: (v) => v.value,
            set: (v, t) => ChatVariable.fromYaml(v.toYaml()..['value'] = t),
          ),
          ConfigField.text(
            label: 'Description',
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
        createNew: () =>
            TimedRequest(id: _newId('tr'), originalText: '', intervalMinutes: 60),
        fields: [
          ConfigField.text(
            label: 'Prompt',
            multiline: true,
            required: true,
            get: (r) => r.originalText,
            set: (r, t) =>
                TimedRequest.fromYaml(r.toYaml()..['originalText'] = t),
          ),
          ConfigField.boolean(
            label: 'Enabled',
            get: (r) => r.enabled,
            set: (r, b) => TimedRequest.fromYaml(r.toYaml()..['enabled'] = b),
          ),
          ConfigField.enumeration<TimedRequest, ScheduleMode>(
            label: 'Schedule mode',
            values: ScheduleMode.values,
            labelOf: (m) => m.value,
            get: (r) => r.scheduleMode,
            set: (r, m) =>
                TimedRequest.fromYaml(r.toYaml()..['scheduleMode'] = m.value),
          ),
          ConfigField.integer(
            label: 'Interval (minutes)',
            positive: true,
            get: (r) => r.intervalMinutes,
            set: (r, n) =>
                TimedRequest.fromYaml(r.toYaml()..['intervalMinutes'] = n),
          ),
        ],
      );

  // ── Agent Settings (singleton) ───────────────────────────────────────────────

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
            get: (s) => s.bridgeHost,
            set: (s, v) => s.copyWith(bridgeHost: v),
          ),
          ConfigField.integer(
            label: 'Port scan start',
            positive: true,
            get: (s) => s.portScanStart,
            set: (s, n) => s.copyWith(portScanStart: n ?? s.portScanStart),
          ),
          ConfigField.integer(
            label: 'Port scan end',
            positive: true,
            get: (s) => s.portScanEnd,
            set: (s, n) => s.copyWith(portScanEnd: n ?? s.portScanEnd),
            validate: (s) => s.hasValidPortRange
                ? null
                : 'Port scan end must be >= port scan start',
          ),
          ConfigField.integer(
            label: 'Default max tokens',
            positive: true,
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
            get: (s) => s.thinkingEnabled ?? false,
            set: (s, b) => s.copyWith(thinkingEnabled: b),
          ),
          ConfigField.boolean(
            label: 'Prompt caching (default)',
            get: (s) => s.promptCachingEnabled ?? false,
            set: (s, b) => s.copyWith(promptCachingEnabled: b),
          ),
        ],
      );
}
