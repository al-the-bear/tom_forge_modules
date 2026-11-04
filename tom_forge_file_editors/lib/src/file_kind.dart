/// Which editor a file opens in, by its name.
library;

/// The kinds of file this package edits.
enum ForgeFileKind {
  /// Markdown: Forge's Markdown editor (tom_md_editor), reviews included.
  markdown,

  /// YAML: Forge's YAML editor (tom_yaml_editor), tree and source.
  yaml,

  /// A `.env` file: entries in a table, values hidden until shown.
  env,

  /// Any other text: the plain-text editor.
  text,
}

/// The kind of the file named [name] (its last path segment).
ForgeFileKind forgeFileKindOf(String name) {
  final lower = name.toLowerCase();
  if (lower == '.env' || lower.startsWith('.env.') || lower.endsWith('.env')) {
    return ForgeFileKind.env;
  }
  if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
    return ForgeFileKind.markdown;
  }
  if (lower.endsWith('.yaml') || lower.endsWith('.yml')) {
    return ForgeFileKind.yaml;
  }
  return ForgeFileKind.text;
}
