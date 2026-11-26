/// A user-visible text as a reference: a resource id with its parameters.
///
/// The configuration description and the other kit types are pure Dart and
/// take no localisation package, so a text they hold is a reference that
/// whoever shows it resolves. Two kinds exist:
///
/// - **An id without English** ([ForgeText.id]), the form of the workspace
///   guideline `i18n.md`: [key] is relative to its package
///   (`actions.saveAction.label`) and is read under the scope of the
///   component that owns it, through a [ForgeTextResolver] (`tom_forge_kit`'s
///   `ForgeTextScope`); the English text is in the package's
///   `lib/resources/<package-name>_en.json` only.
/// - **A key with an English fallback** ([ForgeText.new]), the form of the
///   packages not migrated yet: [key] is absolute (`forge.config.md.title`)
///   and [fallback] is shown where nothing translates it.
///
/// `{name}` placeholders in the text are filled from [params]; a parameter
/// that is itself a [ForgeText] is resolved the same way first (a message
/// naming the item it is about and why). [ForgeText.literal] is a runtime
/// text that nothing looks up.
class ForgeText {
  /// The text under [key], [fallback] when nothing translates it (a package
  /// not migrated yet).
  const ForgeText(this.key, String this.fallback, {this.params = const {}});

  /// The text of the id [key], relative to the owning component's package,
  /// with no English in code: an unresolved one shows its path.
  const ForgeText.id(this.key, {this.params = const {}}) : fallback = null;

  /// A runtime text that is never translated ([key] empty): a font's name,
  /// a choice a provider answers.
  const ForgeText.literal(String text)
    : key = '',
      fallback = text,
      params = const {};

  const ForgeText._(this.key, this.fallback, this.params);

  /// The resource id: relative to its package for a [ForgeText.id], an
  /// absolute key otherwise (`forge.shell.theme.label`); empty for a
  /// [ForgeText.literal], which no lookup is asked for.
  final String key;

  /// The English text shown when no resource has [key]; null for a
  /// [ForgeText.id].
  final String? fallback;

  /// Whether this is a [ForgeText.literal].
  bool get isLiteral => key.isEmpty;

  /// The values of the `{name}` placeholders.
  final Map<String, Object?> params;

  /// The same text with [values] added to its [params].
  ForgeText withParams(Map<String, Object?> values) =>
      ForgeText._(key, fallback, {...params, ...values});

  /// The text: [lookup]'s answer for [key] (when it has one), else
  /// [fallback], else [key] itself (an id nothing resolves shows itself),
  /// with the placeholders filled.
  String resolve([String? Function(String key)? lookup]) => fill(
    key.isEmpty ? fallback ?? '' : lookup?.call(key) ?? fallback ?? key,
    lookup,
  );

  /// [text] with every `{name}` of [params] replaced by its value (a
  /// [ForgeText] value resolved with [lookup]).
  String fill(String text, [String? Function(String key)? lookup]) {
    if (params.isEmpty) return text;
    var out = text;
    params.forEach((name, value) {
      final shown = value is ForgeText ? value.resolve(lookup) : '$value';
      out = out.replaceAll('{$name}', shown);
    });
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is ForgeText &&
      other.key == key &&
      other.fallback == fallback &&
      _sameParams(other.params, params);

  @override
  int get hashCode => Object.hash(key, fallback, params.length);

  static bool _sameParams(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  /// The fallback (or the key) with its placeholders filled.
  @override
  String toString() => resolve();
}

/// Resolves [ForgeText]s for whoever shows them: the owning component's
/// text scope (`tom_forge_kit`'s `ForgeTextScope`), so a pure-Dart type
/// below the kit (an action, a description) can carry the way its texts are
/// read without knowing Tom Core.
abstract interface class ForgeTextResolver {
  /// [text] in the words of the installed text resources.
  String resolve(ForgeText text);
}
