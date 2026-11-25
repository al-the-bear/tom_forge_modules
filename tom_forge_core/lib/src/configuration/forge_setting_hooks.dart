import 'dart:async';

import 'forge_configuration_description.dart' show ForgeIconRef;
import 'forge_key_bindings.dart' show ForgeKeyChord;
import 'forge_setting.dart';
import 'forge_setting_kinds.dart' show ForgeSettingChoice;
import 'forge_text.dart';

// The behaviour a setting can carry, as hooks.
//
// **Data and behaviour are kept apart.** A description is const data: a
// setting names the hooks it uses by id (`ForgeSetting.actions`, a tool
// path's detector, a choice's choices provider, a status line's provider, a
// key binding table's action catalogue). The behaviour itself is an object
// the application or a module supplies at run time through a
// [ForgeSettingHooks] registry, where it can reach what exists only then (the
// editor picker, a probe, an HTTP client, the operating system's fonts).
//
// Why ids rather than objects in the description: a module declares its
// descriptions as constants before anything runs; one description is bound
// to different behaviour in different applications (Forge and Webwork, a
// test); a description can be listed, compared and written out; and a
// missing hook is a finding (`ForgeConfigurationDescription.problems` with
// the registry), not a crash. Every hook is pure Dart, so this library stays
// free of Flutter: a hook answers data (results, candidates, choices, status,
// flow steps) and the UI draws it.

/// How far a hook run is, reported while it runs.
class ForgeHookProgress {
  const ForgeHookProgress({this.fraction, this.message});

  /// Done so far, 0..1; null when unknown (an indeterminate spinner).
  final double? fraction;

  /// What it is doing now.
  final ForgeText? message;
}

/// Lets the user stop a hook run: a hook checks [isCancelled] between its
/// steps (or listens to [whenCancelled]) and ends with
/// [ForgeActionResult.cancelled].
class ForgeHookCancellation {
  ForgeHookCancellation();

  final Completer<void> _cancelled = Completer<void>();

  /// Whether the user asked to stop.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when the user asks to stop.
  Future<void> get whenCancelled => _cancelled.future;

  /// Asks the run to stop.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

/// What a hook is given when it runs: the setting, its value in effect, a
/// way to read the other settings of its description and to write its own
/// value, the registry (to reach other hooks) and the run's progress and
/// cancellation.
///
/// The values service (`tom_forge_kit`'s `ForgeConfigurationValues`) makes
/// it; the functions keep this library free of the kit.
class ForgeSettingContext {
  const ForgeSettingContext({
    required this.setting,
    required this.value,
    required this.hooks,
    this.readSetting,
    this.writeValue,
    this.onProgress,
    this.cancellation,
    this.key,
  });

  /// The setting the hook runs for.
  final ForgeSetting<Object> setting;

  /// Its value in effect when the run started.
  final Object value;

  /// The registry the hook was found in.
  final ForgeSettingHooks hooks;

  /// The value in effect of another setting of the same description, by id
  /// (null when there is none).
  final Object? Function(String settingId)? readSetting;

  /// Writes a value of [setting]; answers why it was refused, or null.
  final Future<ForgeText?> Function(Object? value)? writeValue;

  /// Takes the run's progress.
  final void Function(ForgeHookProgress progress)? onProgress;

  /// The user's stop request, or null when the run cannot be stopped.
  final ForgeHookCancellation? cancellation;

  /// The entry the hook is asked about: a map's key (a choices provider of a
  /// string map's values), a table's row (an action id); null otherwise.
  final String? key;

  /// The value in effect of the setting [settingId] of the same description.
  Object? valueOf(String settingId) => readSetting?.call(settingId);

  /// Writes [newValue] for [setting]; answers why it was refused, or null.
  Future<ForgeText?> write(Object? newValue) async =>
      writeValue == null ? null : await writeValue!(newValue);

  /// Reports progress.
  void progress({double? fraction, ForgeText? message}) =>
      onProgress?.call(ForgeHookProgress(fraction: fraction, message: message));

  /// Whether the user asked to stop.
  bool get isCancelled => cancellation?.isCancelled ?? false;

  /// The same context about [entry] (a map key, a table row).
  ForgeSettingContext about(String? entry) => ForgeSettingContext(
    setting: setting,
    value: value,
    hooks: hooks,
    readSetting: readSetting,
    writeValue: writeValue,
    onProgress: onProgress,
    cancellation: cancellation,
    key: entry,
  );
}

/// How a hook run ended.
enum ForgeActionOutcome {
  /// It did what it should.
  success,

  /// It failed: [ForgeActionResult.message] says why.
  failure,

  /// The user stopped it.
  cancelled,
}

/// What an action or a flow answers when it ends.
class ForgeActionResult {
  const ForgeActionResult({
    required this.outcome,
    this.message,
    this.value,
    this.hasValue = false,
    this.refresh = false,
  });

  /// It worked, optionally with a [message], a new [value] for the setting
  /// (written by the values service) and a [refresh] of the setting's
  /// status and detection.
  const ForgeActionResult.success({
    this.message,
    this.value,
    this.refresh = false,
  }) : outcome = ForgeActionOutcome.success,
       hasValue = value != null;

  /// It failed, because of [message].
  const ForgeActionResult.failure(
    ForgeText this.message, {
    this.refresh = false,
  }) : outcome = ForgeActionOutcome.failure,
       value = null,
       hasValue = false;

  /// The user stopped it.
  const ForgeActionResult.cancelled()
    : outcome = ForgeActionOutcome.cancelled,
      message = null,
      value = null,
      hasValue = false,
      refresh = false;

  final ForgeActionOutcome outcome;

  /// What to tell the user, or null.
  final ForgeText? message;

  /// A new value of the setting (e.g. the path a download installed to),
  /// written when [hasValue].
  final Object? value;

  /// Whether [value] is to be written.
  final bool hasValue;

  /// Whether the setting's status, detection and choices are read again.
  final bool refresh;

  /// Whether it worked.
  bool get succeeded => outcome == ForgeActionOutcome.success;

  @override
  String toString() =>
      'ForgeActionResult(${outcome.name}'
      '${message == null ? '' : ': $message'})';
}

/// The look of an action's button.
enum ForgeActionEmphasis {
  /// The main thing to do (a filled button).
  primary,

  /// An ordinary button (outlined).
  normal,

  /// A quiet one (a text button).
  subtle,
}

/// A command offered as a button beside a setting (or as an action entry of
/// its own): *Check again*, *Download*, *Reload configuration*.
abstract class ForgeSettingAction {
  const ForgeSettingAction();

  /// The id settings name it by.
  String get id;

  /// The button's label.
  ForgeText get label;

  /// The button's icon, or null.
  ForgeIconRef? get icon => null;

  /// A question asked before it runs (*Reset every shortcut?*), or null.
  ForgeText? get confirmation => null;

  /// How prominent the button is.
  ForgeActionEmphasis get emphasis => ForgeActionEmphasis.normal;

  /// Whether it can run now (a disabled button otherwise).
  bool isEnabled(ForgeSettingContext context) => true;

  /// Runs it. Thrown errors are caught by the caller and reported as a
  /// failure.
  Future<ForgeActionResult> run(ForgeSettingContext context);
}

/// A [ForgeSettingAction] made of a function.
class ForgeCallbackAction extends ForgeSettingAction {
  const ForgeCallbackAction({
    required this.id,
    required this.label,
    required this.onRun,
    this.icon,
    this.confirmation,
    this.emphasis = ForgeActionEmphasis.normal,
    this.enabledWhen,
  });

  @override
  final String id;

  @override
  final ForgeText label;

  @override
  final ForgeIconRef? icon;

  @override
  final ForgeText? confirmation;

  @override
  final ForgeActionEmphasis emphasis;

  /// What it does.
  final Future<ForgeActionResult> Function(ForgeSettingContext context) onRun;

  /// Whether it can run now; null: always.
  final bool Function(ForgeSettingContext context)? enabledWhen;

  @override
  bool isEnabled(ForgeSettingContext context) =>
      enabledWhen?.call(context) ?? true;

  @override
  Future<ForgeActionResult> run(ForgeSettingContext context) => onRun(context);
}

/// The level of a status: how a status line or a detected candidate is
/// drawn.
enum ForgeStatusLevel {
  /// Fine (found, usable, valid).
  ok,

  /// Worth knowing, nothing wrong.
  info,

  /// Usable with a reservation (too old, not checked yet).
  warning,

  /// Not usable (missing, damaged, failing).
  error,

  /// Being found out.
  busy,

  /// Not known.
  unknown,
}

/// One line of a status's details (one problem of a list of issues).
class ForgeStatusItem {
  const ForgeStatusItem({required this.level, required this.text, this.detail});

  final ForgeStatusLevel level;

  /// The line (a runtime text: a file name, a message from a tool).
  final String text;

  /// More about it, or null.
  final String? detail;
}

/// What a status provider answers: a level, a message and details.
class ForgeStatusInfo {
  const ForgeStatusInfo({
    required this.level,
    this.message,
    this.detail,
    this.items = const [],
  });

  /// Nothing known yet.
  static const unknown = ForgeStatusInfo(level: ForgeStatusLevel.unknown);

  /// Being found out.
  static const busy = ForgeStatusInfo(level: ForgeStatusLevel.busy);

  final ForgeStatusLevel level;

  /// The message, or null.
  final ForgeText? message;

  /// A runtime detail (a version, a path, a tool's output).
  final String? detail;

  /// The details as lines (issues), possibly empty.
  final List<ForgeStatusItem> items;
}

/// A read-only value or state shown for a setting (a status entry, a tool
/// path's state): read once with [current], or followed with [watch].
abstract class ForgeSettingStatusProvider {
  const ForgeSettingStatusProvider();

  /// The id settings name it by.
  String get id;

  /// The status now.
  Future<ForgeStatusInfo> current(ForgeSettingContext context);

  /// The status as it changes, or null when it is only read on request
  /// (the UI then reads [current] when shown and after an action asks for a
  /// refresh).
  Stream<ForgeStatusInfo>? watch(ForgeSettingContext context) => null;
}

/// A [ForgeSettingStatusProvider] made of functions.
class ForgeCallbackStatusProvider extends ForgeSettingStatusProvider {
  const ForgeCallbackStatusProvider({
    required this.id,
    required this.onCurrent,
    this.onWatch,
  });

  @override
  final String id;

  final Future<ForgeStatusInfo> Function(ForgeSettingContext context) onCurrent;

  final Stream<ForgeStatusInfo> Function(ForgeSettingContext context)? onWatch;

  @override
  Future<ForgeStatusInfo> current(ForgeSettingContext context) =>
      onCurrent(context);

  @override
  Stream<ForgeStatusInfo>? watch(ForgeSettingContext context) =>
      onWatch?.call(context);
}

/// Choices known only at run time (the editors that open a file type, the
/// fonts of the system), possibly per entry ([ForgeSettingContext.key]: a
/// string map's key).
abstract class ForgeChoicesProvider {
  const ForgeChoicesProvider();

  /// The id settings name it by.
  String get id;

  /// The choices for [context] (its `key` when the setting asks per entry).
  Future<List<ForgeSettingChoice>> choices(ForgeSettingContext context);

  /// Fires when the choices may have changed (a module registered another
  /// editor); null when they do not change while shown.
  Stream<void>? get changes => null;
}

/// A [ForgeChoicesProvider] made of a function.
class ForgeCallbackChoicesProvider extends ForgeChoicesProvider {
  const ForgeCallbackChoicesProvider({
    required this.id,
    required this.onChoices,
    this.changes,
  });

  @override
  final String id;

  final Future<List<ForgeSettingChoice>> Function(ForgeSettingContext context)
  onChoices;

  @override
  final Stream<void>? changes;

  @override
  Future<List<ForgeSettingChoice>> choices(ForgeSettingContext context) =>
      onChoices(context);
}

/// Where an auto-detection looks: the hints a description gives a detector
/// (a tool path's `hints`). Every list may be empty; the detector decides
/// how to use them and may know more places itself.
class ForgeDetectionHints {
  const ForgeDetectionHints({
    this.candidatePaths = const [],
    this.searchRoots = const [],
    this.executableNames = const [],
    this.environmentVariables = const [],
    this.searchPath = true,
    this.maxDepth = 2,
    this.extra = const {},
  });

  /// Exact paths to try first (`/Applications/LibreOffice.app`); `~` is the
  /// home folder, `$VAR` an environment variable.
  final List<String> candidatePaths;

  /// Folders to search below, [maxDepth] levels deep.
  final List<String> searchRoots;

  /// The executables' names to look for (`soffice`, `pandoc`), without the
  /// platform's extension.
  final List<String> executableNames;

  /// Environment variables naming the tool's path or home (`JAVA_HOME`).
  final List<String> environmentVariables;

  /// Whether the folders of `PATH` are searched for [executableNames].
  final bool searchPath;

  /// How deep [searchRoots] are searched.
  final int maxDepth;

  /// Anything else a particular detector understands.
  final Map<String, Object?> extra;

  /// These hints with [other]'s lists added (the description's and the
  /// application's hints).
  ForgeDetectionHints merge(ForgeDetectionHints other) => ForgeDetectionHints(
    candidatePaths: [...candidatePaths, ...other.candidatePaths],
    searchRoots: [...searchRoots, ...other.searchRoots],
    executableNames: [...executableNames, ...other.executableNames],
    environmentVariables: [
      ...environmentVariables,
      ...other.environmentVariables,
    ],
    searchPath: searchPath || other.searchPath,
    maxDepth: maxDepth > other.maxDepth ? maxDepth : other.maxDepth,
    extra: {...extra, ...other.extra},
  );

  /// Whether nothing is hinted.
  bool get isEmpty =>
      candidatePaths.isEmpty &&
      searchRoots.isEmpty &&
      executableNames.isEmpty &&
      environmentVariables.isEmpty &&
      extra.isEmpty;
}

/// One place a detector found (or checked): the value to take, its level,
/// its version and why it is not usable.
class ForgeDetectedCandidate {
  const ForgeDetectedCandidate({
    required this.value,
    required this.level,
    this.version,
    this.reason,
    this.message,
    this.source,
  });

  /// Nothing found ([reason]: why).
  const ForgeDetectedCandidate.missing({this.reason, this.message})
    : value = '',
      level = ForgeStatusLevel.error,
      version = null,
      source = null;

  /// The value the setting takes for it (a path).
  final String value;

  /// Usable ([ForgeStatusLevel.ok]), with a reservation, or not.
  final ForgeStatusLevel level;

  /// Its version, when it could be read.
  final String? version;

  /// Why it is not usable, as the tool said it (runtime text).
  final String? reason;

  /// What to tell the user about it, or null.
  final ForgeText? message;

  /// Where it was found (`PATH`, `JAVA_HOME`, a search root), or null.
  final String? source;

  /// Whether it can be used.
  bool get usable => level == ForgeStatusLevel.ok;

  /// Whether this is no candidate at all.
  bool get isMissing => value.isEmpty;

  @override
  String toString() =>
      'ForgeDetectedCandidate(${level.name} $value ${version ?? ''})';
}

/// Finds a setting's value by itself (a tool's path): [check] reports on
/// the value set (or, when none is set, what the usual search finds), and
/// [detect] searches widely for every candidate, for the user to pick one.
abstract class ForgeSettingDetector {
  const ForgeSettingDetector();

  /// The id settings name it by.
  String get id;

  /// The state of [value] (`context.value`); when [value] is empty, the
  /// candidate the usual search finds (missing when none).
  Future<ForgeDetectedCandidate> check(
    ForgeSettingContext context,
    String value,
    ForgeDetectionHints hints,
  );

  /// Every candidate a wide search finds, best first.
  Future<List<ForgeDetectedCandidate>> detect(
    ForgeSettingContext context,
    ForgeDetectionHints hints,
  );
}

/// A [ForgeSettingDetector] made of functions.
class ForgeCallbackDetector extends ForgeSettingDetector {
  const ForgeCallbackDetector({
    required this.id,
    required this.onCheck,
    required this.onDetect,
  });

  @override
  final String id;

  final Future<ForgeDetectedCandidate> Function(
    ForgeSettingContext context,
    String value,
    ForgeDetectionHints hints,
  )
  onCheck;

  final Future<List<ForgeDetectedCandidate>> Function(
    ForgeSettingContext context,
    ForgeDetectionHints hints,
  )
  onDetect;

  @override
  Future<ForgeDetectedCandidate> check(
    ForgeSettingContext context,
    String value,
    ForgeDetectionHints hints,
  ) => onCheck(context, value, hints);

  @override
  Future<List<ForgeDetectedCandidate>> detect(
    ForgeSettingContext context,
    ForgeDetectionHints hints,
  ) => onDetect(context, hints);
}

// ── Flows ──

/// What a flow step asks of the user.
enum ForgeFlowStepKind {
  /// Information, optionally with a [ForgeFlowStep.url] to open and a
  /// [ForgeFlowStep.code] to copy (an OAuth device code), and choices.
  show,

  /// Fields to fill in ([ForgeFlowStep.fields]: a token, a one-time code).
  input,

  /// Waiting for something outside (the browser sign-in, a poll); the UI
  /// shows [ForgeFlowStep.message] and asks the session again with
  /// [ForgeFlowSession.poll] after [ForgeFlowStep.pollAfter].
  waiting,

  /// Finished: [ForgeFlowStep.result].
  done,
}

/// How a flow field is typed.
enum ForgeFlowFieldKind {
  /// Free text.
  text,

  /// A secret, hidden while typed (a token, a password).
  secret,

  /// A one-time code (digits, [ForgeFlowField.length] long).
  oneTimeCode,
}

/// A field of an input step.
class ForgeFlowField {
  const ForgeFlowField({
    required this.id,
    required this.label,
    this.kind = ForgeFlowFieldKind.text,
    this.hint,
    this.length,
    this.required = true,
  });

  /// The key of its value in [ForgeFlowResponse.values].
  final String id;

  final ForgeText label;

  final ForgeFlowFieldKind kind;

  final ForgeText? hint;

  /// The exact length of a one-time code, or null.
  final int? length;

  /// Whether the step cannot go on without it.
  final bool required;
}

/// A choice offered by a step (a button): its [id] comes back in
/// [ForgeFlowResponse.choice].
class ForgeFlowChoice {
  const ForgeFlowChoice(this.id, this.label, {this.primary = false});

  final String id;

  final ForgeText label;

  /// Whether it is the step's main button.
  final bool primary;
}

/// One step of a flow, as the session answers it; the UI draws it and
/// answers with a [ForgeFlowResponse].
class ForgeFlowStep {
  const ForgeFlowStep({
    required this.kind,
    this.title,
    this.message,
    this.url,
    this.code,
    this.fields = const [],
    this.choices = const [],
    this.pollAfter,
    this.result,
    this.error,
  });

  /// Information with choices (default: one *Continue*).
  const ForgeFlowStep.show({
    this.title,
    this.message,
    this.url,
    this.code,
    this.choices = const [],
    this.error,
  }) : kind = ForgeFlowStepKind.show,
       fields = const [],
       pollAfter = null,
       result = null;

  /// Fields to fill in.
  const ForgeFlowStep.input({
    required this.fields,
    this.title,
    this.message,
    this.choices = const [],
    this.error,
  }) : kind = ForgeFlowStepKind.input,
       url = null,
       code = null,
       pollAfter = null,
       result = null;

  /// Waiting; polled again after [pollAfter].
  const ForgeFlowStep.waiting({
    this.title,
    this.message,
    this.url,
    this.code,
    this.pollAfter = const Duration(seconds: 2),
  }) : kind = ForgeFlowStepKind.waiting,
       fields = const [],
       choices = const [],
       result = null,
       error = null;

  /// Finished with [result].
  const ForgeFlowStep.done(ForgeActionResult this.result)
    : kind = ForgeFlowStepKind.done,
      title = null,
      message = null,
      url = null,
      code = null,
      fields = const [],
      choices = const [],
      pollAfter = null,
      error = null;

  final ForgeFlowStepKind kind;
  final ForgeText? title;
  final ForgeText? message;

  /// A URL for the user to open (the provider's sign-in page).
  final String? url;

  /// A code for the user to copy or enter elsewhere (a device code).
  final String? code;

  final List<ForgeFlowField> fields;
  final List<ForgeFlowChoice> choices;

  /// When a waiting step is asked again.
  final Duration? pollAfter;

  /// How the flow ended (a done step).
  final ForgeActionResult? result;

  /// Why the previous answer was refused (a wrong code), shown with the step.
  final ForgeText? error;
}

/// The user's answer to a step: the [choice] made and the [values] typed.
class ForgeFlowResponse {
  const ForgeFlowResponse({this.choice, this.values = const {}});

  /// The id of the choice (a [ForgeFlowChoice]); null: the default
  /// *Continue*.
  final String? choice;

  /// The fields' values by field id.
  final Map<String, String> values;
}

/// One run of a flow: the UI asks [start] for the first step, then answers
/// each step with [respond] (or, while waiting, asks [poll]) until a done
/// step; [cancel] stops it at any point.
abstract class ForgeFlowSession {
  /// The first step.
  Future<ForgeFlowStep> start();

  /// The step after the user's [response] to the current one.
  Future<ForgeFlowStep> respond(ForgeFlowResponse response);

  /// The step after a waiting step's wait (the same waiting step again while
  /// nothing happened).
  Future<ForgeFlowStep> poll();

  /// Stops the flow; the UI closes it.
  void cancel();
}

/// A multi-step interaction a setting starts (signing in with OAuth,
/// entering a one-time code, pairing a device): the description names it like
/// an action (`ForgeSetting.actions`, `ForgeActionSetting.flow`), the
/// application supplies it, and the UI drives its steps.
abstract class ForgeSettingFlow {
  const ForgeSettingFlow();

  /// The id settings name it by.
  String get id;

  /// The button that starts it.
  ForgeText get label;

  /// The button's icon, or null.
  ForgeIconRef? get icon => null;

  /// A new run for [context].
  ForgeFlowSession start(ForgeSettingContext context);
}

// ── Key binding tables ──

/// One action a key binding table lists (`ForgeKeyBindingTableSetting`):
/// supplied at run time by the application's action catalogue.
class ForgeCatalogueAction {
  const ForgeCatalogueAction({
    required this.id,
    required this.label,
    this.scope,
    this.defaultBinding,
    this.group,
  });

  /// The action id the override is stored under (`md.bold`, `*.bold`).
  final String id;

  /// What the user sees (a runtime label).
  final String label;

  /// Where it is active (`editorFocus`, an editor id); null: everywhere.
  final String? scope;

  /// Its binding while nothing overrides it (one stroke, or a chord of two
  /// or more); null: unbound.
  final ForgeKeyChord? defaultBinding;

  /// A group heading (an editor's name), or null.
  final String? group;
}

/// The actions a key binding table lists, known only at run time.
abstract class ForgeActionCatalogue {
  const ForgeActionCatalogue();

  /// The id settings name it by.
  String get id;

  /// The actions.
  Future<List<ForgeCatalogueAction>> actions(ForgeSettingContext context);

  /// Fires when the actions may have changed; null when they do not.
  Stream<void>? get changes => null;
}

/// A [ForgeActionCatalogue] made of a function.
class ForgeCallbackActionCatalogue extends ForgeActionCatalogue {
  const ForgeCallbackActionCatalogue({
    required this.id,
    required this.onActions,
    this.changes,
  });

  @override
  final String id;

  final Future<List<ForgeCatalogueAction>> Function(ForgeSettingContext context)
  onActions;

  @override
  final Stream<void>? changes;

  @override
  Future<List<ForgeCatalogueAction>> actions(ForgeSettingContext context) =>
      onActions(context);
}

// ── The registry ──

/// The behaviour the settings name, by id: actions, flows, detectors,
/// choices providers, status providers and action catalogues, supplied by
/// the application and its modules at run time.
///
/// A module hands its hooks over with the kit's
/// `ForgeConfigurationHooksExtra`; the kit merges them
/// (`forgeConfigurationHooksOf`) and the values service holds the registry,
/// from which the tiles run them. A later registration of an id replaces
/// the earlier one.
class ForgeSettingHooks {
  ForgeSettingHooks({
    Iterable<ForgeSettingAction> actions = const [],
    Iterable<ForgeSettingFlow> flows = const [],
    Iterable<ForgeSettingDetector> detectors = const [],
    Iterable<ForgeChoicesProvider> choices = const [],
    Iterable<ForgeSettingStatusProvider> statuses = const [],
    Iterable<ForgeActionCatalogue> catalogues = const [],
  }) {
    actions.forEach(addAction);
    flows.forEach(addFlow);
    detectors.forEach(addDetector);
    choices.forEach(addChoices);
    statuses.forEach(addStatus);
    catalogues.forEach(addCatalogue);
  }

  final Map<String, ForgeSettingAction> _actions = {};
  final Map<String, ForgeSettingFlow> _flows = {};
  final Map<String, ForgeSettingDetector> _detectors = {};
  final Map<String, ForgeChoicesProvider> _choices = {};
  final Map<String, ForgeSettingStatusProvider> _statuses = {};
  final Map<String, ForgeActionCatalogue> _catalogues = {};

  void addAction(ForgeSettingAction action) => _actions[action.id] = action;
  void addFlow(ForgeSettingFlow flow) => _flows[flow.id] = flow;
  void addDetector(ForgeSettingDetector detector) =>
      _detectors[detector.id] = detector;
  void addChoices(ForgeChoicesProvider provider) =>
      _choices[provider.id] = provider;
  void addStatus(ForgeSettingStatusProvider provider) =>
      _statuses[provider.id] = provider;
  void addCatalogue(ForgeActionCatalogue catalogue) =>
      _catalogues[catalogue.id] = catalogue;

  ForgeSettingAction? action(String id) => _actions[id];
  ForgeSettingFlow? flow(String id) => _flows[id];
  ForgeSettingDetector? detector(String id) => _detectors[id];
  ForgeChoicesProvider? choices(String id) => _choices[id];
  ForgeSettingStatusProvider? status(String id) => _statuses[id];
  ForgeActionCatalogue? catalogue(String id) => _catalogues[id];

  /// Whether a hook of any type has [id].
  bool has(String id) =>
      _actions.containsKey(id) ||
      _flows.containsKey(id) ||
      _detectors.containsKey(id) ||
      _choices.containsKey(id) ||
      _statuses.containsKey(id) ||
      _catalogues.containsKey(id);

  /// Every id registered.
  Set<String> get ids => {
    ..._actions.keys,
    ..._flows.keys,
    ..._detectors.keys,
    ..._choices.keys,
    ..._statuses.keys,
    ..._catalogues.keys,
  };

  /// Adds every hook of [other] (its ids replace these).
  void addAll(ForgeSettingHooks other) {
    _actions.addAll(other._actions);
    _flows.addAll(other._flows);
    _detectors.addAll(other._detectors);
    _choices.addAll(other._choices);
    _statuses.addAll(other._statuses);
    _catalogues.addAll(other._catalogues);
  }

  /// A registry of every hook of [registries], later ones replacing earlier
  /// ids.
  static ForgeSettingHooks merged(Iterable<ForgeSettingHooks> registries) {
    final out = ForgeSettingHooks();
    for (final registry in registries) {
      out.addAll(registry);
    }
    return out;
  }
}
