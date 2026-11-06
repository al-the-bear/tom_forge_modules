# Integrated UX Patterns

How combined editor components behave as one tool: the interaction rules
every editor, view, module and application in the Forge shell follows, so
that a user moving between them meets one way of working. Each pattern names
where the shell implements it and the tests that pin it (paths under
`tom_forge_ui/test/` unless stated). The platform layers are in
[platform_architecture.md](platform_architecture.md), what an editor must
provide in [editor_component_contract.md](editor_component_contract.md).

## P1. One active editor receives the editing actions

Cut, copy, paste, undo, redo, select all and the line actions are the
shell's (action bar, menus, shortcuts, command palette); the shell runs them
on the **active editor** only, through its `EditorActionProvider`, and
enables them from that editor's `stateSnapshot`. No editor registers a
global handler of its own.

- Code: `DefaultShellApi.executeAction`, `ForgeEditor` (`EditorActionProvider`
  defaults), `StandardEditingActions`.
- Tests: `widgets/action_bar_state_test.dart` 01–04.
- Detail: the workspace's `_copilot_guidelines/global_actions_coordination.md`,
  `tom_forge_ui/doc/editor_action_externalization.md`.

## P2. One table of keys; undo keys reach the document

Every shortcut is in the shell's one table (`ForgeShortcutManager`), the user
can rebind it, and an editor's local key map says what that table says. No
two bindings share a key. The undo keys are the platform's (Primary+Z,
Shift+Primary+Z, Ctrl+Y off macOS) and reach the focused editor's document
— never a text field's own history; a text field outside the editors keeps
its keys. A key whose action did nothing is not consumed.

- Tests: `widgets/wonecmpc18_undo_key_routing_test.dart` KR-1–KR-8,
  `services/forge_shortcut_manager_test.dart`,
  `widgets/phase_g_configuration_and_shortcuts_test.dart`.
- Detail: `tom_forge_ui/_copilot_guidelines/editor_history_contract.md` §4.

## P3. Context menus are contributions

A right-click menu is drawn by the shell from `ForgeModule.contextMenus`
contributions at a target (explorer rows, or a target an editor or view
reports through `shell.contextMenus.show`); an entry that does not apply is
drawn disabled with the reason as its tooltip. No component builds its own
`showMenu`.

- Tests: `widgets/module_context_menu_test.dart`,
  `widgets/wonecmpc16_application_scoped_contributions_test.dart` AS-4.
- Detail: [context_menu_contributions.md](context_menu_contributions.md).

## P4. One document, one editor

Opening a file that is open activates its editor (and moves to the line
asked for); no second editor of the document is made. A module that owns a
kind of document opens it itself, before anything reads it as text. When
several editors fit a file, **Open With** lets the user choose, and the
user's default editor for an extension (Settings) is used without asking.

- Code: `DefaultLayoutController.openFile`, `openFileWith`.
- Tests: `widgets/ux_patterns_test.dart` UX-1,
  `services/module_open_uri_test.dart`,
  `widgets/phase_j_navigation_and_open_with_test.dart` 07–09,
  `widgets/phase_s_file_types_and_settings_navigation_test.dart`.

## P5. A split copy is the same document

Splitting a middle panel shows a second view of the same document with one
history: every edit, undo and redo appears in both.

- Tests: the undo conformance check `splitCopiesShareHistory`, run by every
  document editor (the register in
  [editor_component_contract.md](editor_component_contract.md) §2);
  `widgets/phase_u_dirty_status_keyboard_test.dart` 07.

## P6. Nothing unsaved is lost without asking

An editor whose document differs from the saved state shows it (an asterisk
on its tab). Closing a dirty editor asks Save / Don't Save / Cancel; closing
an application whose module vetoes asks with the reason; quitting asks once,
for every open application's vetoes and unsaved editors together, and quits
without a question when nothing objects. Autosave, when switched on, writes a
dirty editor after the idle delay.

- Tests: `widgets/phase_y_autosave_dirty_notification_test.dart` 05–09,
  `widgets/phase_u_dirty_status_keyboard_test.dart` 01 and 09,
  `widgets/wonecmpc15_application_lifecycle_test.dart` LC-2–LC-6 and
  QT-1–QT-3, `widgets/phase_bd_panel_tab_and_editor_lifecycle_test.dart` 06
  and 10.

## P7. A change on disk is never written over silently

A file changed outside the editor while it is open is not overwritten by a
save: the user keeps theirs or takes the file. Content taken from outside
the history (a reload, an external change, a revision restore) is shown in
every view, is the saved state and leaves nothing to undo; an editor that
cannot take it in place is closed and the file opened again.

- Tests: `tom_forge_file_editors/test/file_editors_module_test.dart` FE-3,
  `undo/wonecmpc19_history_contract_test.dart` HC-2, the conformance check
  `replaceContentClearsHistory`.

## P8. Each application keeps its own state

Switching between applications keeps each one's middle groups, open editors,
active group, panel sizes and selected side-panel tabs; a full-screen
application keeps its view in the tree. What is contributed follows the
active application: its actions under their ids and shortcuts, its
status-bar items, its context-menu entries. Every application's layout
survives a restart.

- Tests: `widgets/wonecmpc16_application_scoped_contributions_test.dart`
  AS-1–AS-7, `widgets/wonecmpc13_full_screen_application_test.dart`,
  `widgets/qim_none3_application_layouts_test.dart`.

## P9. Focus can be moved and seen

The keyboard moves the focus between the visible panels and to a numbered
middle panel; the focused panel shows a focus ring in every theme (high
contrast included); a full-screen application's view gets the focus back
when its application is activated again.

- Tests: `widgets/accessibility_test.dart`,
  `widgets/phase_f_shell_interaction_test.dart` 08,
  `widgets/phase_k_quick_open_and_panel_lifecycle_test.dart` 08,
  `widgets/wonecmpc13_full_screen_application_test.dart`.

## P10. Feedback has one place for each kind

Long work reports progress in the status bar; messages are notifications
(toasts that dismiss, with a history); problems are diagnostics in the
Problems view; tool output goes to output channels. A component reports
through these managers rather than with toasts, spinners or problem lists of
its own; what it shows inline is the state of its own content (a chat view's
reconnect banner, a document that could not be opened).

- Code: `ForgeProgressManager`, `ForgeNotificationManager`,
  `ForgeDiagnosticManager`, `ForgeOutputChannelManager` on `ForgeShellApi`.
- Tests: `widgets/phase_v_dialogs_drag_progress_test.dart` 05,
  `widgets/forge_status_bar_test.dart`,
  `widgets/phase_bc_find_notify_overlay_shortcuts_test.dart` 05–06,
  `widgets/phase_t_tab_context_and_notifications_test.dart` 06–09,
  `services/service_unit_test.dart`.

## P11. No control is shown that cannot act

A button, menu entry or item is shown only when something can run it; one
that does not apply right now is disabled and says why (P3). A control that
could never act is not shown: the title bar has no Back / Forward buttons
until navigation history exists
(`later13_akfu-navigation-history-back-forward`).

- Tests: `widgets/phase_j_navigation_and_open_with_test.dart` 02.

## P12. The chrome is readable in every theme

Every visible text run of the shell's chrome meets WCAG AA (4.5:1 for text,
3:1 for icons) in the light, dark and high-contrast themes; an empty state
or a hint uses the theme's `onSurfaceVariant`, not a faded `onSurface`.
Animations give way to static indicators where the user asked for reduced
motion or high contrast.

- Tests: `golden/shell_golden_test.dart` SHELL-C (the readability scan
  `expectTomReadable` from `tom_reusable_ui/testing.dart`, per theme) and
  its pixel goldens, `widgets/forge_status_bar_test.dart` (static progress
  indicator).
