/// A user-visible string as a resource key with its English fallback.
///
/// The configuration description is pure Dart and takes no localisation
/// package: a label is a [key] an application's text resources translate and
/// a [fallback] shown where nothing translates it (a headless tool, an
/// application without resources). `tom_configuration_ui` resolves it through
/// Tom Core's text resources (`TomTextResourceProvider`); [resolve] does the
/// same with any lookup.
///
/// `{name}` placeholders in the text are filled from [params], in the
/// translated text as in the fallback; a parameter that is itself a
/// [ForgeText] is resolved with the same lookup (a message naming the item it
/// is about and why).
class ForgeText {
  /// The text under [key], [fallback] when nothing translates it.
  const ForgeText(this.key, this.fallback, {this.params = const {}});

  /// The resource key, e.g. `forge.shell.theme.label`.
  final String key;

  /// The English text shown when no resource has [key].
  final String fallback;

  /// The values of the `{name}` placeholders.
  final Map<String, Object?> params;

  /// The same text with [values] added to its [params].
  ForgeText withParams(Map<String, Object?> values) =>
      ForgeText(key, fallback, params: {...params, ...values});

  /// The text: [lookup]'s answer for [key] (when it has one) or [fallback],
  /// with the placeholders filled.
  String resolve([String? Function(String key)? lookup]) =>
      fill(lookup?.call(key) ?? fallback, lookup);

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

  /// The fallback with its placeholders filled.
  @override
  String toString() => resolve();
}
