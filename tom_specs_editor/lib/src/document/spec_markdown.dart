import 'package:flutter/material.dart';

/// Inline markdown renderer used for every label, help text and content
/// preview in the document editor (§13, requirements *j*/*m*).
///
/// This is the single seam through which the editor renders authored markdown.
/// The §13 target is for `SpecMarkdown` to wrap `tom_md_editor`'s
/// `MdPreviewPanel`, but that widget is a whole-document, section-navigating
/// preview *panel* (it owns an `MdEditorController` and parses the text into
/// navigable sections) — the wrong granularity for the dozens of short inline
/// labels/previews a compact tree shows, and it would pull the full
/// `tom_md_editor` dependency surface (flutter_markdown, math, svg, …) into the
/// editor. So this first cut renders a lightweight subset inline; swapping the
/// body for `MdPreviewPanel` (full fidelity) is tracked as a CS deferral.
///
/// Supported subset: ATX headings (`#`–`######`), unordered list items
/// (`-`/`*`), `**bold**`/`*italic*`/`` `code` `` inline spans, and blank-line
/// paragraph breaks. Anything else renders verbatim. The widget is read-only —
/// editing happens through the field editors, not here.
class SpecMarkdown extends StatelessWidget {
  const SpecMarkdown(
    this.source, {
    super.key,
    this.style,
    this.muted = false,
  });

  /// The markdown source to render.
  final String source;

  /// Base text style; falls back to the ambient body style.
  final TextStyle? style;

  /// When true, renders in the muted on-surface-variant colour (for help text).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = (style ?? theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(
      color: muted ? theme.colorScheme.onSurfaceVariant : null,
    );
    final blocks = <Widget>[];
    for (final line in source.split('\n')) {
      blocks.add(_lineWidget(context, line, base));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  Widget _lineWidget(BuildContext context, String raw, TextStyle base) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) return const SizedBox(height: 6);

    // ATX headings: count leading '#'s (1–6).
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final text = heading.group(2)!;
      final size = (base.fontSize ?? 14) + (7 - level) * 1.5;
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: Text.rich(
          _inlineSpans(text, base.copyWith(
            fontSize: size,
            fontWeight: FontWeight.bold,
          )),
        ),
      );
    }

    // Unordered list items.
    final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, top: 1, bottom: 1),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '• ', style: base),
            ..._inlineSpans(bullet.group(1)!, base).children!,
          ]),
        ),
      );
    }

    return Text.rich(_inlineSpans(line, base));
  }

  /// Parses `**bold**`, `*italic*` and `` `code` `` spans within [text].
  TextSpan _inlineSpans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*([^*]+)\*\*)|(\*([^*]+)\*)|(`([^`]+)`)');
    var index = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > index) {
        spans.add(TextSpan(text: text.substring(index, m.start), style: base));
      }
      if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(2),
            style: base.copyWith(fontWeight: FontWeight.bold)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
            text: m.group(4),
            style: base.copyWith(fontStyle: FontStyle.italic)));
      } else if (m.group(6) != null) {
        spans.add(TextSpan(
            text: m.group(6),
            style: base.copyWith(fontFamily: 'monospace')));
      }
      index = m.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: base));
    }
    return TextSpan(children: spans);
  }
}
