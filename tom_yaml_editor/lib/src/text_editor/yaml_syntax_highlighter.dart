import 'package:flutter/painting.dart';
import 'package:tom_text_highlight/tom_text_highlight.dart';

/// The YAML editor's highlighter: the shared [YamlHighlighter] (one YAML
/// tokenizer for the Forge editors and `tom_file_editors`) styled with the
/// editor's [YamlHighlightColors].
class YamlSyntaxHighlighter extends YamlHighlighter {
  YamlSyntaxHighlighter({this.colors = const YamlHighlightColors()})
      : super(theme: colors.theme);

  final YamlHighlightColors colors;
}

/// The YAML editor's colours, one per kind of token.
class YamlHighlightColors {
  final Color key;
  final Color string;
  final Color number;
  final Color boolean;
  final Color nullValue;
  final Color comment;
  final Color punctuation;
  final Color colon;
  final Color dash;
  final Color bracket;

  const YamlHighlightColors({
    this.key = const Color(0xFF9CDCFE),
    this.string = const Color(0xFFCE9178),
    this.number = const Color(0xFFB5CEA8),
    this.boolean = const Color(0xFF569CD6),
    this.nullValue = const Color(0xFF569CD6),
    this.comment = const Color(0xFF6A9955),
    this.punctuation = const Color(0xFF808080),
    this.colon = const Color(0xFFDCDCAA),
    this.dash = const Color(0xFF4EC9B0),
    this.bracket = const Color(0xFFC586C0),
  });

  /// The [YamlHighlighter] token classes in these colours: quoted and plain
  /// scalars alike in [string], document markers and block scalar
  /// indicators in [punctuation].
  HighlightTheme get theme => HighlightTheme({
        'attr': TextStyle(color: key),
        'punctuation.colon': TextStyle(color: colon),
        'bullet': TextStyle(color: dash),
        'comment': TextStyle(color: comment),
        'meta': TextStyle(color: punctuation),
        'punctuation.block': TextStyle(color: punctuation),
        'punctuation.bracket': TextStyle(color: bracket),
        'string': TextStyle(color: string),
        'plain': TextStyle(color: string),
        'literal.boolean': TextStyle(color: boolean),
        'literal.null': TextStyle(color: nullValue),
        'number': TextStyle(color: number),
      });
}
