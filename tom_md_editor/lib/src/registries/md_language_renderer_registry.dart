import 'package:flutter/widgets.dart';

import '../theme/md_editor_theme.dart';

/// A renderer for a specific set of code-block languages.
class MdLanguageRenderer {
  const MdLanguageRenderer({
    required this.languages,
    required this.renderer,
  });

  /// Language identifiers this renderer handles.
  final List<String> languages;

  /// Builder that renders the code content as a widget.
  final Widget Function(String code, MdBasicTheme theme) renderer;
}

/// Registry of custom language renderers for code blocks.
///
/// When a code block's language matches a registered renderer, the custom
/// renderer is used in the preview instead of the default code display.
class MdLanguageRendererRegistry {
  MdLanguageRendererRegistry([List<MdLanguageRenderer>? renderers]) {
    if (renderers != null) {
      for (final r in renderers) {
        register(r);
      }
    }
  }

  final Map<String, MdLanguageRenderer> _renderers = {};

  /// Register a custom renderer for its declared languages.
  void register(MdLanguageRenderer renderer) {
    for (final lang in renderer.languages) {
      _renderers[lang.toLowerCase()] = renderer;
    }
  }

  /// Build a custom renderer for [language], or `null` if none registered.
  Widget? buildRenderer(String language, String code, MdBasicTheme theme) {
    final r = _renderers[language.toLowerCase()];
    return r?.renderer(code, theme);
  }

  /// Whether a custom renderer exists for [language].
  bool hasRenderer(String language) {
    return _renderers.containsKey(language.toLowerCase());
  }
}
