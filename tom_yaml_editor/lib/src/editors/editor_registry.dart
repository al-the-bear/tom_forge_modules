import 'package:flutter/material.dart';

import '../yaml_editor_theme.dart';

/// Factory function that creates an embedded editor widget for a given value.
///
/// Parameters:
/// - [key]: the YAML key (e.g. "script-dart")
/// - [value]: the current scalar value
/// - [onChanged]: callback when the value changes
/// - [theme]: the parent editor's theme
/// - [readOnly]: whether the editor is read-only
typedef EditorFactory =
    Widget Function({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    });

/// Factory function for a full-size pop-out editor widget.
///
/// Uses the same contract as [EditorFactory], but is intended for larger,
/// focused editing surfaces opened from an inline embedded editor.
typedef PopoutEditorFactory =
    Widget Function({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    });

/// Callback to override editor resolution for specific keys.
///
/// Return an [EditorSuffix] to use a custom editor, or `null` to fall back
/// to the default resolution (suffix convention → schema metadata → type).
///
/// ```dart
/// EditorResolver myResolver = (key, path, schemaEditorType) {
///   if (key == 'special-field') return mySpecialEditor;
///   return null; // fall back to default
/// };
/// ```
typedef EditorResolver =
    EditorSuffix? Function(
      String key,
      List<String> path,
      String? schemaEditorType,
    );

/// A registered editor suffix (e.g. "dart", "markdown", "regex").
class EditorSuffix {
  /// The suffix string (e.g. "dart").
  final String suffix;

  /// Human-readable label for this editor type.
  final String label;

  /// The factory that creates the editor widget.
  final EditorFactory factory;

  /// Optional icon to display in the UI.
  final IconData? icon;

  /// Whether this editor supports opening a full-size pop-out editor.
  final bool supportsPopout;

  /// Optional factory for the full-size pop-out editor UI.
  ///
  /// If omitted and [supportsPopout] is true, [factory] is reused.
  final PopoutEditorFactory? popoutFactory;

  /// Optional title shown in the pop-out header.
  final String? popoutTitle;

  const EditorSuffix({
    required this.suffix,
    required this.label,
    required this.factory,
    this.icon,
    this.supportsPopout = false,
    this.popoutFactory,
    this.popoutTitle,
  });
}

/// Registry of embedded editors keyed by suffix convention.
///
/// The YAML schema editor looks up this registry when rendering a scalar
/// value whose key matches the `key-<suffix>` pattern.
///
/// The registry is **immutable**: [register] and [unregister] return new
/// instances. Use assignment, not cascade:
///
/// ```dart
/// var registry = EditorRegistry();
/// registry = registry.register(EditorSuffix(
///   suffix: 'dart',
///   label: 'Dart Code',
///   factory: ({key, value, onChanged, theme, readOnly}) {
///     return MyDartEditorWidget(
///       code: value as String? ?? '',
///       onChanged: (code) => onChanged(code),
///     );
///   },
/// ));
/// ```
///
/// For full control over editor assignment, set [resolver]:
///
/// ```dart
/// registry = registry.withResolver((key, path, schemaEditorType) {
///   if (key.endsWith('-custom')) return myCustomEditor;
///   return null; // fall back to suffix-based lookup
/// });
/// ```
class EditorRegistry {
  final Map<String, EditorSuffix> _editors;

  /// Optional callback that overrides suffix-based resolution.
  ///
  /// When set, this is called first for every scalar key. If it returns
  /// non-null, that editor is used. Otherwise, the standard suffix/schema
  /// lookup proceeds.
  final EditorResolver? resolver;

  /// Creates an empty registry.
  const EditorRegistry({this.resolver}) : _editors = const {};

  /// Creates a registry with default built-in editors.
  factory EditorRegistry.defaults({EditorResolver? resolver}) {
    return EditorRegistry._withEditors({}, resolver: resolver);
  }

  EditorRegistry._withEditors(this._editors, {this.resolver});

  /// Register a new editor suffix.
  ///
  /// Returns a new registry with the editor added (immutable pattern).
  /// Use assignment: `registry = registry.register(editor);`
  EditorRegistry register(EditorSuffix editor) {
    return EditorRegistry._withEditors({
      ..._editors,
      editor.suffix: editor,
    }, resolver: resolver);
  }

  /// Remove a registered editor suffix.
  ///
  /// Returns a new registry with the editor removed.
  EditorRegistry unregister(String suffix) {
    var copy = Map<String, EditorSuffix>.from(_editors);
    copy.remove(suffix);
    return EditorRegistry._withEditors(copy, resolver: resolver);
  }

  /// Return a new registry with a custom [resolver] callback.
  ///
  /// The resolver is called before suffix lookup, giving the host app
  /// full control over which editor renders for any given key.
  EditorRegistry withResolver(EditorResolver? resolver) {
    return EditorRegistry._withEditors(_editors, resolver: resolver);
  }

  /// Resolve the editor for a specific [key] at [path].
  ///
  /// Resolution order:
  /// 1. Custom [resolver] callback (if set)
  /// 2. Suffix extracted from [key] looked up in the registry
  /// 3. [schemaEditorType] from JSON Schema `x-editor-type` looked up
  /// 4. Returns `null` → host uses a default scalar widget
  EditorSuffix? resolve(
    String key,
    List<String> path, {
    String? schemaEditorType,
  }) {
    // 1. Custom resolver
    if (resolver != null) {
      var result = resolver!(key, path, schemaEditorType);
      if (result != null) return result;
    }

    // 2. Schema x-editor-type
    if (schemaEditorType != null && _editors.containsKey(schemaEditorType)) {
      return _editors[schemaEditorType];
    }

    // 3. Key suffix convention
    var suffix = _extractSuffix(key);
    if (suffix != null && _editors.containsKey(suffix)) {
      return _editors[suffix];
    }

    return null;
  }

  /// Extract the type suffix from a key name.
  static String? _extractSuffix(String key) {
    var lastDash = key.lastIndexOf('-');
    if (lastDash <= 0 || lastDash == key.length - 1) return null;
    return key.substring(lastDash + 1);
  }

  /// Look up an editor by suffix directly.
  EditorSuffix? operator [](String suffix) => _editors[suffix];

  /// Whether a suffix is registered.
  bool has(String suffix) => _editors.containsKey(suffix);

  /// All registered suffixes.
  Iterable<String> get suffixes => _editors.keys;

  /// All registered editors.
  Iterable<EditorSuffix> get editors => _editors.values;
}
