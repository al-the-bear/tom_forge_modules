# The editor history contract

Every Forge editor keeps its undo history the same way. The rules below are
checked by the conformance harness (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`),
which every editor's suite runs, and the shared helpers in
`tom_editors_shared` (`lib/src/text_editing/history/`) implement them once.

## 1. One history per document, owned by the document

A document has exactly one history, held by its model — not by a widget.
Every view of the document uses it: tree and source view, edit and preview,
and the split copy (`ForgeEditor.buildCopy`), which shows the same document
and the same history, never a second stack.

- A file-backed editor's history is its `ForgeFileSession`
  (`tom_file_session`) — the plain-text editor's is — unless the editor owns a richer model that is the
  document (the specs editor's `SpecDocumentController`, Webwork's
  per-document `WebworkUndoStack`).
- A text editor without either keeps a `ForgeTextHistory`.
- An editor embedded in a document that keeps the history (a Dart field
  in a spec document, Webwork's script section) keeps none: it reports its
  edits and gesture ends to the host and takes undo and redo from it — the
  Dart editor's external history mode (`DartCodeHistoryHost`). Every field
  of a spec document — its Dart fields, its plain content and form fields,
  its headlines — writes its typing to the document at once and the
  document makes it one entry per gesture
  (`SpecDocumentController.typeContent` / `typeFormField` /
  `typeHeadline`, ended by `endTyping`); the plain fields are wrapped in
  `ForgeEditorOwnsUndo`, so their undo keys undo the document. A list
  item's section id commits on Enter or blur, its undo keys too go to the
  document.
- The shell's `ForgeUndoManager` holds **shell actions only** (file
  operations). No editor pushes into it; `Edit > Undo/Redo` run the active
  editor's `forge.edit.undo` / `forge.edit.redo` and are disabled with no
  active editor.

## 2. Dirty is measured against the saved state

`ForgeEditor.isDirty` compares the document with a saved marker — the saved
text, a fingerprint or a revision id (`ForgeSavedMarker`). It is never
"can undo" and never "anything changed": undoing back to the saved state
shows clean, undoing past a save shows dirty. `markClean` moves the marker
and leaves the history alone. A caret move, a click or a selection never makes
a document dirty.

An editor that saves its own file (a `ForgeFileSession`: its encoding kept,
the disk checked first) lists `forge.file.save` in its actions and returns
null from `getContent`; the shell then hands every explicit save to it and
never marks it clean itself.

## 3. Content from outside replaces, saves and clears

A reload, an external change the user takes and a revision restore all arrive
through `ForgeEditor.replaceContent(content)`:

- every view shows the new content;
- it is the saved state (clean);
- the history is cleared, for every kind — an entry made against the old
  text would apply to text it was not made on.

An editor that cannot replace in place returns false, and the shell closes it
and opens the file again (`DefaultShellApi.restoreFileFromRevision`), so no
editor stays on the old text. `ForgeTextHistory.replace`,
`MdEditorController.replaceContent`, `YamlEditorController.replaceContent`
and `DartCodeController.replaceCode` are the in-place paths.

## 4. Flutter's own text undo is off

Every `TextField`/`EditableText` keeps an `UndoHistory` and answers the
platform undo keys with it. An editor that keeps the document's history wraps
its text fields in `ForgeEditorOwnsUndo`, which overrides `UndoTextIntent` and
`RedoTextIntent` with actions that do nothing. Put it outside the editor's own
`Shortcuts` (built with `buildEditorShortcutMap`), so the editor's keys reach
its own history first. A field shown outside the editor's key map (a popout
route) passes `onUndo`/`onRedo`, so the platform's keys reach the document's
history there. `tom_file_editors`' `TomTextSource` (`hostOwnsUndo`, with
`handleHistoryKeys: false` when the editor's key map routes the keys) and
`ForgeTextField` (`undoOwnedByHost`) do this themselves for a host that keeps
the history.

A field that shows one value of the document (a tree field) keeps no history
of its own: it writes each change through the document, drops the echo of a
value set from outside (an undo), and puts the caret at the change
(`forgeCaretAtChange`).

## 5. Typing is grouped, flushed at every boundary, and stores the caret

- One entry per gesture: edits with no pause longer than `forgeTypingPause`
  (1.5 s, the same pause `ForgeFileSession` uses) and no caret move between
  them.
- Each entry stores the text and the selection before and after; undo puts
  the caret back where it was before the edit, redo where it was after.
- Pending typing is flushed at every boundary — an editor that holds typing
  back for a while (the Markdown raw editor's preview debounce) hands it to
  the history first, through `MdEditorController.pendingEditFlusher`: undo and redo flush first (a
  word undone inside the pause is undone, not lost or applied late), and the
  editor flushes on save, mode switch and blur (`ForgeTextHistory.flush`).
- Typing after an undo ends the redo future.

## 6. Only real changes, only after they applied

No entry for a change that changed nothing (typing back to where a gesture
started, a caret move). An entry is recorded only for an edit that already
applied — `ForgeTextHistory.edited` is called after the change — and undo and
redo apply first and move the entry second (`TomUndoStack`), so a failed
application leaves the entry where it was.

## 7. One depth setting

`ForgeTextSettings.maxUndoHistory` (Settings → editor → Max undo history) is
the depth of every editor's history. An editor follows it with
`forgeFollowUndoDepth(integration, setDepth)`, which applies it at once and
whenever the host's text settings change (`ForgeShellApi.textSettingsChanged`,
`ForgeEditorIntegration.textSettingsChanged`); `TomUndoStack.maxEntries` can be
changed on an open history. There is no per-editor undo switch or depth.

## 8. Undo history is not persisted

`ForgeEditor.getUndoHistoryMetadata` / `restoreUndoHistoryMetadata` and the
shell's `.forge/undo/` load and save stay as the mechanism, and every editor
returns null: no history outlives its session. A persisted history is a
second record of the document's past that diverges from the file the first
time the file changes elsewhere; an editor that implements it later must tie
it to the file's saved revision. `ForgeEditor.historyManager` (back/forward
navigation, not undo) is likewise reserved.

## 9. The conformance harness

`runForgeUndoConformance(name, create, skip: ...)` from
`package:tom_forge_ui_testing/tom_forge_ui_testing.dart` runs six checks against an editor:

| Check | What it asserts |
|-------|-----------------|
| `dirtyFollowsSavedState` | clean after undoing to the saved state, dirty after undoing past a save |
| `caretAfterUndoAndRedo` | caret before the edit after undo, after it after redo |
| `typingUndoneWithinPause` | typing undone inside the pause is undone, nothing arrives late |
| `noRedoAfterTyping` | typing after an undo leaves nothing to redo |
| `splitCopiesShareHistory` | the copy shows every edit, undo and redo |
| `replaceContentClearsHistory` | replaced content shown everywhere, clean, nothing to undo |

The editor's suite supplies a `ForgeUndoSubject`; the defaults drive an editor
whose views edit through an `EditableText`. A check the editor does not meet
yet is skipped with the todo that makes it pass. Every document editor runs
it (the register is in `tom_ai/forge_modules/_agent_guidelines/editor_component_contract.md`
§2, checked by `tom_forge_app/test/editor_component_contract_test.dart`). Every
document editor passes every check: the YAML editor in both modes, the Dart,
the Markdown and the plain-text editor, the file editors, the website config
editor and the TomSpecs file editor (whose fields record the caret before and
after each typing gesture in the undo entry, `SpecDocumentController
.restoredCaretFor`). An editor that saves its own file overrides the
subject's `saved()` to save (the plain-text editor saves through its session). The reference editor in
`test/undo/undo_conformance_test.dart` — the helpers and nothing else — meets
all six.
