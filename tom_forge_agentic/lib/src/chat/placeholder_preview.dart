import 'package:flutter/material.dart';

/// A live, read-only preview of a placeholder-bearing [source] string with its
/// supported placeholders expanded (§11.5, OE-14).
///
/// Expansion is delegated to [compose] — typically `SpecPromptComposer.compose`
/// in the editor — so this widget stays decoupled from the placeholder engine
/// (`tom_core_agentic`) and is reusable across the composer (§11.1) and the
/// config editors (§12 — "live placeholder preview").
///
/// `compose` may throw — notably `PlaceholderExpressionsUnsupportedError` for
/// the deliberately disabled `${{ … }}` form (§11.5). The preview catches *any*
/// error and renders its message inline in the error colour rather than letting
/// it escape and break the surrounding editor: a half-typed `${{` must never
/// crash the panel the user is typing into. An empty [source] renders
/// [emptyHint] instead.
class PlaceholderPreview extends StatelessWidget {
  const PlaceholderPreview({
    super.key,
    required this.source,
    required this.compose,
    this.emptyHint = 'Nothing to preview yet.',
  });

  /// The raw, placeholder-bearing text to expand.
  final String source;

  /// Expands the supported placeholders in [source]; may throw for unsupported
  /// forms (the preview renders the error rather than propagating it).
  final String Function(String source) compose;

  /// Shown when [source] is empty/whitespace, so the preview slot is never a
  /// bare empty box.
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (source.trim().isEmpty) {
      return Text(
        emptyHint,
        key: const Key('placeholder-preview-empty'),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    String body;
    var isError = false;
    try {
      body = compose(source);
    } on Object catch (error) {
      body = '$error';
      isError = true;
    }
    return SelectableText(
      body,
      key: const Key('placeholder-preview-body'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: isError ? theme.colorScheme.error : null,
      ),
    );
  }
}
