# Tom Forge — Copilot Guidelines

Guidelines specific to the **Tom Forge** repository and its editor components.
Read these before modifying any component in `tom_forge/`.

---

## Documents

| Document | Purpose |
|----------|---------|
| [debug_mode.md](debug_mode.md) | **MANDATORY** — Debug mode pattern: static switch, event trail, heartbeat, error intercept |

---

## Key Rules (Quick Reference)

- **Debug mode is permanent.** Every editor component MUST have an `*_trail.dart`
  file with a `const bool kXxxEditorDebug` switch. See [debug_mode.md](debug_mode.md).
- **Never remove trail infrastructure** — flip the flag to `false` if the output
  is unwanted, but keep the code.
- **Adding a new editor component?** Copy the pattern from `tom_yaml_editor/lib/src/tree/editor_trail.dart`
  and add a row to the table in [debug_mode.md](debug_mode.md).
