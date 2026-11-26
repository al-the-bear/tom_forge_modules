import 'package:tom_core_kernel/tom_core_kernel.dart'
    show TomResourceException, TomScope, TomTextResourceProvider;
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeText, ForgeTextResolver;

/// Reads texts the way the workspace guideline `i18n.md` says code that is no
/// widget reads them: under the scope its component was constructed in.
///
/// A [ForgeTextScope] captures `TomScope.current` when it is constructed. A
/// module, a service or a controller holds one (a module has its own:
/// `ForgeKitModule.textScope`), and an application constructs the component
/// inside the scope it mounts the component's package under, exactly as it
/// does for a widget. [resolve] then reads a [ForgeText.id]'s id as
/// `<scope path>.<id>` from the application's `TomTextResourceProvider`, so
/// a package mounted under two scopes has two independent sets of texts.
///
/// A [ForgeText] of a package not migrated yet (an absolute key with an
/// English fallback) resolves as before: its key is tried under the scope,
/// then alone, then its fallback is shown.
///
/// This is Forge's local abstraction for texts outside widgets; Tom Core's
/// own scoped text accessor (tom_core `txtscoped1`) will take its inner part
/// over.
class ForgeTextScope implements ForgeTextResolver {
  /// A text scope of [scope], by default of `TomScope.current`.
  ForgeTextScope([TomScope? scope]) : scope = scope ?? TomScope.current;

  /// The text scope of the root scope: an id is read as it is written.
  static final ForgeTextScope root = ForgeTextScope(TomScope.defaultScope);

  /// The Tom scope texts are read under.
  final TomScope scope;

  /// The scope's path (`workbench.shell`; empty at the root).
  String get path => scope.getScopePath();

  /// The full resource path of [id] under this scope.
  String pathOf(String id) {
    final path = this.path;
    return path.isEmpty ? id : '$path.$id';
  }

  /// [text] in the installed text resources' words: an id under this scope;
  /// a key with a fallback under this scope, then alone, then the fallback;
  /// a literal as it is. An id nothing resolves shows its full path.
  /// Parameters are filled, a [ForgeText] parameter resolved the same way.
  @override
  String resolve(ForgeText text) {
    if (text.isLiteral) return _fill(text.fallback ?? '', text.params);
    final scoped = forgeTextLookup(pathOf(text.key));
    final found = scoped ?? (path.isEmpty ? null : forgeTextLookup(text.key));
    return _fill(found ?? text.fallback ?? pathOf(text.key), text.params);
  }

  /// The text of [id] (relative to the owning package) with [params].
  String text(String id, {Map<String, Object?> params = const {}}) =>
      resolve(ForgeText.id(id, params: params));

  String _fill(String text, Map<String, Object?> params) {
    if (params.isEmpty) return text;
    var out = text;
    params.forEach((name, value) {
      final shown = value is ForgeText ? resolve(value) : '$value';
      out = out.replaceAll('{$name}', shown);
    });
    return out;
  }

  @override
  String toString() => 'ForgeTextScope(${path.isEmpty ? '<root>' : path})';
}

/// The revision of the application's text resources at which none were
/// installed, or null.
int? _missingAt;

/// The text the application's `TomTextResourceProvider` holds under [key],
/// or null: none, or no text resources installed.
///
/// Without installed resources `getAppResources()` throws an exception that
/// logs itself; the answer is then remembered until the resources change
/// (`TomTextResourceProvider.appResourcesRevision`), so the log shows it
/// once and not once per text.
String? forgeTextLookup(String key) {
  final revision = TomTextResourceProvider.appResourcesRevision.get();
  if (_missingAt == revision) return null;
  try {
    return TomTextResourceProvider.getAppResources().getTextOrNull(key);
  } on TomResourceException {
    _missingAt = revision;
    return null;
  }
}

/// Whether the application has installed text resources (asked as
/// [forgeTextLookup] asks, without logging more than once per revision).
bool get forgeTextResourcesInstalled {
  final revision = TomTextResourceProvider.appResourcesRevision.get();
  if (_missingAt == revision) return false;
  try {
    TomTextResourceProvider.getAppResources();
    return true;
  } on TomResourceException {
    _missingAt = revision;
    return false;
  }
}
