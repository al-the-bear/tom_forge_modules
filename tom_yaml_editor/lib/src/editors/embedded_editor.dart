import 'package:flutter/material.dart';

import '../yaml_editor_theme.dart';
import 'editor_registry.dart';

/// State passed to an [EmbeddedEditor] so it can interact with the host.
class EmbeddedEditorState {
  /// The YAML key this editor belongs to (e.g. "script-dart").
  final String key;

  /// The detected suffix (e.g. "dart").
  final String suffix;

  /// The full YAML path to this node (e.g. ["prompt", "script-dart"]).
  final List<String> path;

  /// Current scalar value.
  final Object? value;

  /// Whether the editor should be read-only.
  final bool readOnly;

  /// Callback to update the value.
  final ValueChanged<Object?> onChanged;

  /// The resolved [EditorSuffix] from the registry, if available.
  final EditorSuffix? editorSuffix;

  /// The host theme, so embedded editors can adapt their styling.
  final YamlEditorTheme theme;

  const EmbeddedEditorState({
    required this.key,
    required this.suffix,
    required this.path,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    required this.theme,
    this.editorSuffix,
  });

  /// Create a copy with optional overrides.
  EmbeddedEditorState copyWith({
    String? key,
    String? suffix,
    List<String>? path,
    Object? value,
    bool? readOnly,
    ValueChanged<Object?>? onChanged,
    EditorSuffix? editorSuffix,
    YamlEditorTheme? theme,
  }) {
    return EmbeddedEditorState(
      key: key ?? this.key,
      suffix: suffix ?? this.suffix,
      path: path ?? this.path,
      value: value ?? this.value,
      readOnly: readOnly ?? this.readOnly,
      onChanged: onChanged ?? this.onChanged,
      editorSuffix: editorSuffix ?? this.editorSuffix,
      theme: theme ?? this.theme,
    );
  }
}

/// Abstract base class for embedded editors.
///
/// Implementations should extend this to create custom editors that
/// render inline within the YAML tree view for matching key suffixes.
///
/// ```dart
/// class DartEmbeddedEditor extends EmbeddedEditor {
///   const DartEmbeddedEditor({super.key});
///
///   @override
///   Widget build(BuildContext context, EmbeddedEditorState state) {
///     return MyDartCodeWidget(
///       code: state.value as String? ?? '',
///       onChanged: state.readOnly ? null : (v) => state.onChanged(v),
///     );
///   }
/// }
/// ```
abstract class EmbeddedEditor extends StatelessWidget {
  const EmbeddedEditor({super.key});

  /// Build the editor widget given the host [state].
  ///
  /// Override this in subclasses to provide the actual embedded editor UI.
  Widget buildEditor(BuildContext context, EmbeddedEditorState state);
}
