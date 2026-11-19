# tom_forge_file_editors

The file editors of a Forge shell. Each edits one file through a
`ForgeFileSession` (`tom_file_session`): the file is read in its encoding, a
save writes the text back as splices — encoding, byte-order mark, line endings
and every untouched byte kept — after checking that the file on disk is still
the one read, and a file changed elsewhere is never written over (a banner
offers *Keep mine* / *Take theirs*). Every editor saves its own file: it lists
`forge.file.save`, the shell hands it the save and never writes it.

| Kind | Editor | History |
| --- | --- | --- |
| Markdown (`.md`) | `ForgeMarkdownFileEditor` — Forge's Markdown editor (`tom_md_editor`), reviews included | the editor's controller |
| YAML (`.yaml`, `.yml`) | `ForgeYamlFileEditor` — Forge's YAML editor (`tom_yaml_editor`), tree and source | the editor's controller |
| todo file (`*.todo.yaml`) | `ForgeTodoFileEditor` — `tom_todo_ui`'s todo-file editor: the todos as rows with the details editor, the schema the file names checked, archive and delete to the siblings, *All files* over the shell's file system, the YAML source | the file session |
| `.env` | `ForgeEnvFileEditor` — `tom_file_editors`' `.env` editor: a table, values hidden until shown | the file session |
| any other text | `ForgePlainTextEditor` (`tom_forge_ui`) | the file session |

Every one passes Forge's undo conformance harness with no check skipped.

## Opening files

`ForgeFileEditorsModule` opens the files of the shell's file system in the
editor of their kind (`forgeFileKindOf`), through `ForgeModule.openUri`, and
shows a file already open again rather than opening it twice:

```dart
final module = ForgeFileEditorsModule(
  // A host replaces the editor of a kind…
  builders: {ForgeFileKind.markdown: (session, shell, shellModule) => …},
  // …and leaves a file to another module.
  claims: (uri) => !uri.path.endsWith('tom.website-editor.yaml'),
);
module.activate(shell);
(shell.modules as DefaultModuleRegistry).register(module);
```

**Open With.** The module offers, for a file it opens, the editor of its kind
and every `ForgeFileEditorAlternative` a host gave it whose `matches` accepts
the file (`editorChoicesFor`). Choosing an alternative builds its editor
(`build(uri, shell)`) or shows the one already open on the file; choosing the
kind's editor never shows an alternative. An ordinary open shows whichever
editor of the module is already on the file.

```dart
ForgeFileEditorsModule(
  alternatives: [
    ForgeFileEditorAlternative(
      id: 'tomspecs',
      label: 'TomSpecs Editor',
      icon: Icons.article_outlined,
      matches: isTomSpecsFile,
      build: (uri, shell) => SpecFileEditor(…),
    ),
  ],
);
```

The `.env` editor copies a value through a `ForgeProtectedClipboard`; the
default writes it to the system clipboard and clears it after 30 seconds
unless something else was copied.

The todo-file editor is checked before Markdown and YAML, so a
`*.todo.yaml` is a todo file. Its *All files* view lists every todo file of
the shell's file system; choosing a row opens that file — or shows it, when it
is already open — with the todo selected. Forge keeps no identity, so a todo
added or completed here records no author; the board and moving todos to
other places are additions a host makes to the editor, and Forge makes
neither.

## Testing

The test-support package `tom_forge_file_editors_testing` (a dev_dependency)
holds how to drive each editor
through Forge's undo conformance harness (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`)
— `ForgeMarkdownFileSubject`, `ForgeYamlFileSubject`, `ForgeTextFileSubject`,
`ForgeEnvFileSubject`, `ForgeTodoFileSubject`, each over an editor the caller
made — so an app composing the module runs the same checks on the editors it
opens.

## License

BSD-3-Clause — see [LICENSE](LICENSE). The package names no Webwork package;
`tom_file_editors` and `tom_todo_ui` are BSD-3 Tom UI modules in `tom_modules`.
