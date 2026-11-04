import 'package:flutter/material.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

/// Inline markdown renderer used for every label, help text and content preview
/// in the document editor (`tom_specs_editor_specification.md` §13,
/// requirements *j*/*m*).
///
/// This is the single seam through which the editor renders authored markdown.
/// `tom_specs_editor_specification.md` §13 j asks `SpecMarkdown` to wrap
/// `tom_md_editor`'s `MdPreviewPanel`, but that widget is a whole-document,
/// section-navigating preview *panel* (it owns an `MdEditorController`, parses
/// the text into navigable sections, and needs a bounded height) — the wrong
/// granularity for the dozens of short inline labels a compact tree shows. So
/// `SpecMarkdown` pays the panel's weight only **where it is justified**
/// (OE-3): when the source actually uses rich markdown features the lightweight
/// renderer cannot show — fenced code blocks, GFM tables, math, or embedded
/// images. Plain labels, help text and prose (the overwhelming majority) keep
/// the lightweight inline renderer: no controller, no panel chrome, no
/// bounded-height container.
///
/// Lightweight subset: ATX headings (`#`–`######`), unordered list items
/// (`-`/`*`), `**bold**`/`*italic*`/`` `code` `` inline spans, and blank-line
/// paragraph breaks. Anything richer is routed to `MdPreviewPanel`. The widget
/// is read-only — editing happens through the field editors, not here.
class SpecMarkdown extends StatelessWidget {
  const SpecMarkdown(this.source, {super.key, this.style, this.muted = false});

  /// The markdown source to render.
  final String source;

  /// Base text style; falls back to the ambient body style.
  final TextStyle? style;

  /// When true, renders in the muted on-surface-variant colour (for help text).
  final bool muted;

  /// Maximum height of the rich (`MdPreviewPanel`) preview before it scrolls.
  /// The panel is internally scrollable and needs a bounded height; a label or
  /// content preview should never dominate the tree, so it is capped.
  static const double _richMaxHeight = 320;

  @override
  Widget build(BuildContext context) {
    if (_isRichMarkdown(source)) {
      return _RichMarkdown(source: source, maxHeight: _richMaxHeight);
    }
    final theme = Theme.of(context);
    final base = (style ?? theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: muted ? theme.colorScheme.onSurfaceVariant : null);
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
          _inlineSpans(
            text,
            base.copyWith(fontSize: size, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // Unordered list items.
    final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, top: 1, bottom: 1),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '• ', style: base),
              ..._inlineSpans(bullet.group(1)!, base).children!,
            ],
          ),
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
        spans.add(
          TextSpan(
            text: m.group(2),
            style: base.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (m.group(4) != null) {
        spans.add(
          TextSpan(
            text: m.group(4),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(6) != null) {
        spans.add(
          TextSpan(
            text: m.group(6),
            style: base.copyWith(fontFamily: 'monospace'),
          ),
        );
      }
      index = m.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: base));
    }
    return TextSpan(children: spans);
  }
}

/// Fenced code block opener (``` or ~~~), anywhere in the source.
final RegExp _kFenceRe = RegExp(r'^[ \t]*(```|~~~)', multiLine: true);

/// GFM table delimiter row, e.g. `| --- | :--: |` or `--- | ---`.
final RegExp _kTableRe = RegExp(
  r'^[ \t]*\|?[ \t]*:?-{3,}:?[ \t]*\|',
  multiLine: true,
);

/// Markdown image embed `![alt](src)`.
final RegExp _kImageRe = RegExp(r'!\[[^\]]*\]\([^)]+\)');

/// Block math `$$ … $$`, or inline `$ … $` carrying a TeX-ish token
/// (`\cmd`, `^`, `_`, `{}`) so plain currency like `$5` does not trip it.
final RegExp _kMathRe = RegExp(r'\$\$[\s\S]+?\$\$|\$[^$\n]*[\\^_{}][^$\n]*\$');

/// Whether [source] uses markdown features the lightweight inline renderer
/// cannot show — the only case where the heavier [MdPreviewPanel] is justified
/// (`tom_specs_editor_specification.md` §13 j/m, OE-3). Conservative on
/// purpose: a false negative degrades to the (correct, lighter) inline
/// renderer; a false positive only wastes a panel. Exposed for unit testing the
/// routing without building widgets.
bool isRichMarkdown(String source) => _isRichMarkdown(source);

bool _isRichMarkdown(String source) {
  if (source.isEmpty) return false;
  return _kFenceRe.hasMatch(source) ||
      _kTableRe.hasMatch(source) ||
      _kImageRe.hasMatch(source) ||
      _kMathRe.hasMatch(source);
}

/// Read-only rich preview backed by `tom_md_editor`'s [MdPreviewPanel]
/// (tables/math/mermaid/images, `tom_specs_editor_specification.md` §13 j/m).
/// Owns a short-lived [MdEditorController] seeded from the source; rebuilt in
/// place when the source changes and disposed with the widget. Bounded +
/// internally scrollable because the panel lays its body out with `Expanded`.
class _RichMarkdown extends StatefulWidget {
  const _RichMarkdown({required this.source, required this.maxHeight});

  final String source;
  final double maxHeight;

  @override
  State<_RichMarkdown> createState() => _RichMarkdownState();
}

class _RichMarkdownState extends State<_RichMarkdown> {
  late final MdEditorController _controller = MdEditorController(
    initialMarkdown: widget.source,
  );

  @override
  void didUpdateWidget(_RichMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _controller.replaceContent(widget.source);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = MdEditorSettings.viewer();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: MdPreviewPanel(
        controller: _controller,
        theme: MdEditorTheme.fromThemeData(Theme.of(context)),
        settings: settings,
        // All rich plugins enabled regardless of the viewer settings flags so
        // tables/math/mermaid render whenever the content uses them.
        pluginRegistry: MdPluginRegistry([
          MdTablePlugin(),
          MdMathPlugin(),
          MdMermaidPlugin(),
          MdCodePlugin(),
        ]),
      ),
    );
  }
}
