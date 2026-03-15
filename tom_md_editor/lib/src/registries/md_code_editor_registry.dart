import 'package:flutter/widgets.dart';

/// Registration entry for a custom code editor widget.
class MdCodeEditorRegistration {
  const MdCodeEditorRegistration({
    required this.languages,
    required this.editorBuilder,
    this.displayName,
    this.icon,
  });

  /// Language identifiers this editor handles (e.g. `['dart', 'python']`).
  final List<String> languages;

  /// Builder that creates the editor widget for the given code.
  final Widget Function(String code, ValueChanged<String> onChanged)
      editorBuilder;

  /// Human-readable name for display in UI selectors.
  final String? displayName;

  /// Optional icon for the editor.
  final IconData? icon;
}

/// Registry of custom code editor widgets indexed by language.
///
/// When a code block's language matches a registered entry, the custom
/// editor is used instead of the default text editor overlay.
class MdCodeEditorRegistry {
  MdCodeEditorRegistry([List<MdCodeEditorRegistration>? registrations]) {
    if (registrations != null) {
      for (final reg in registrations) {
        register(reg);
      }
    }
  }

  final Map<String, MdCodeEditorRegistration> _editors = {};

  /// Register a custom code editor for its declared languages.
  void register(MdCodeEditorRegistration registration) {
    for (final lang in registration.languages) {
      _editors[lang.toLowerCase()] = registration;
    }
  }

  /// Build a custom editor widget for [language], or `null` if none registered.
  Widget? buildEditor(
    String language,
    String code,
    ValueChanged<String> onChanged,
  ) {
    final reg = _editors[language.toLowerCase()];
    return reg?.editorBuilder(code, onChanged);
  }

  /// Whether a custom editor exists for [language].
  bool hasCustomEditor(String language) {
    return _editors.containsKey(language.toLowerCase());
  }
}
