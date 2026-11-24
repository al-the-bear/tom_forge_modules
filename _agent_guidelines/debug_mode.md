# Debug Mode — Tom Forge Components

> **⚠ MANDATORY PATTERN — applies to ALL Tom Forge editor components.**
> Every component in `tom_forge/` MUST implement debug mode using the pattern
> described here. Never remove the debug infrastructure. Never make it
> conditional at compile time in a way that silences it in debug builds.

---

## What Is It

Each editor component (YAML editor, Dart editor, etc.) has a permanent
in-code debug mode that is enabled or disabled with a **single top-level
`bool` flag**, `false` by default, at the top of a dedicated `*_trail.dart`
file in `lib/src/`. The flag is `const` unless the component lets a host or a
test switch it at run time, which its file then says (the YAML and Markdown
editors do). Off by default because the trail's `FlutterError.onError`
intercept replaces the handler of every host the component is embedded in, a
test harness included.

When enabled (`true`), the debug mode:
- Emits timestamped trail events to `debugPrint` for every meaningful action,
  state transition, focus change, and controller operation
- Starts a heartbeat `Timer` (1 second) so you can confirm the main isolate is alive
- Intercepts `FlutterError.onError` to route Flutter framework errors to the trail
- Wraps all hot paths in `try/catch` and reports exceptions via `FlutterError.reportError`

When disabled (`false`), every trace call is a **zero-cost no-op** — the `const`
flag lets the compiler eliminate all dead code.

---

## Flag Location and Naming

| Component | File | Flag |
|-----------|------|------|
| YAML Editor (`tom_yaml_editor`) | `lib/src/tree/editor_trail.dart` | `kYamlEditorDebug` (switchable at run time) |
| Markdown Editor (`tom_md_editor`) | `lib/src/integration/editor_trail.dart` | `kMdEditorIntegrationDebug` (switchable at run time) |
| Dart Editor (`tom_dart_editor`) | `lib/src/editor_trail.dart` | `kDartEditorDebug` |
| Quest applications (`tom_forge_quests`) | `lib/src/quests_trail.dart` | `kForgeQuestsDebug` |
| PDF editor (`tom_ai/modules/tom_pdf_editor`) | `lib/src/pdf_editor_trail.dart` | `kPdfEditorDebug` (switchable at run time) |
| Office editor (`tom_ai/modules/tom_office_editor`) | `lib/src/office_editor_trail.dart` | `kOfficeEditorDebug` (switchable at run time), prefix `[OE]` |
| ZetaOffice view (`tom_ai/modules/tom_office_zetaoffice`) | `lib/src/trail.dart` | `kZetaOfficeDebug` (switchable at run time), prefix `[ZO]` |
| External Tools section (`tom_forge_ui`) | `lib/src/tools/external_tools_trail.dart` | `kForgeExternalToolsDebug` (switchable at run time), prefix `[FT]` |
| PDFium editor in Forge (`tom_forge_pdf_pdfium`) | `lib/src/forge_pdf_trail.dart` | `kForgePdfiumDebug` (switchable at run time), prefix `[FP]` |
| pdf.js editor in Forge (`tom_forge_pdf_pdfjs`) | `lib/src/forge_pdfjs_trail.dart` | `kForgePdfJsDebug` (switchable at run time), prefix `[FPJ]` |
| LibreOfficeKit editor in Forge (`tom_forge_office_lok`) | `lib/src/forge_office_trail.dart` | `kForgeOfficeDebug` (switchable at run time), prefix `[FO]` |
| ZetaOffice editor in Forge (`tom_forge_office_zetaoffice`) | `lib/src/forge_zetaoffice_trail.dart` | `kForgeZetaOfficeDebug` (switchable at run time), prefix `[FZO]` |

`tom_forge_app/test/editor_component_contract_test.dart` (EC-4) checks that
every editor component has such a trail with its switch off.

Each component owns its own flag. Flags are **independent** — you can enable
just the YAML editor trail without activating the Dart editor trail.

A built app switches the run-time flags on from its command line:
`tom_forge_app --trail=pdf <file.pdf>` sets `kForgePdfiumDebug`,
`kForgePdfJsDebug` and `kPdfEditorDebug` (`ForgeLaunch`, `tom_forge_app/lib/src/forge_launch.dart`).
The two examples take the same option for the YAML editor they show:
`--trail=yaml` sets `kYamlEditorDebug`, `--trail=kit` the kit's
`kShellEditorIntegrationDebug` (`KitLaunch` in `tom_forge_single_window_example`,
`LiteLaunch` in `tom_forge_lite_example`).
A release build prints nothing to stdout; read its trail with
`/usr/bin/log show --predicate 'process == "tom_forge_app"'` (in zsh, `log`
is a builtin).

---

## Pattern (canonical implementation)

```dart
// lib/src/tree/editor_trail.dart  (or lib/src/editor_trail.dart)

import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — <Component Name>
// ============================================================
// true  → event trail + heartbeat + FlutterError intercept enabled
// false → zero-cost no-op (compiler eliminates all trace calls)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Flip to true whenever investigating freezes, unexpected rebuilds,
// lost actions, or any other hard-to-reproduce runtime behaviour.
// ============================================================
const bool kXxxEditorDebug = false; // replace Xxx with component name

/// Log a timestamped event to the console (no-op when [kXxxEditorDebug] is false).
///
/// Filter output with the component prefix:
///   flutter run 2>&1 | grep '\[XX\]'
void trailEvent(String event) {
  if (!kXxxEditorDebug) return;
  final now = DateTime.now();
  final ts = '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[XX $ts] $event'); // replace XX with two-letter component code
}
```

### Heartbeat + FlutterError (in the root editor State)

```dart
// In initState() of the component's root StatefulWidget:
if (kXxxEditorDebug) {
  _prevFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    trailEvent('FlutterError: ${details.exceptionAsString()}');
    _prevFlutterErrorHandler?.call(details);
  };
  _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
    trailEvent('heartbeat');
  });
}

// In dispose():
_heartbeat?.cancel();
if (kXxxEditorDebug) {
  FlutterError.onError = _prevFlutterErrorHandler;
}
```

---

## What to Instrument

Add `trailEvent(...)` calls at every point that is useful for reproducing a
problem. Standard events to cover:

| Category | Events to log |
|----------|--------------|
| User gestures | Right-click opens (with key path), action selected |
| Controller mutations | `applyEdit` (kind + path), `undo`, `redo` |
| Async pipeline | Start + each major step inside `_rebuildTree`, `_computeKeyWidths` |
| Focus changes | `_textInputFocused` old → new value |
| State machine steps | `onControllerChanged` start/end, `setState` phase |
| Exception sites | Every `catch` block — log the exception and call `FlutterError.reportError` |

---

## Console Filter

Each component uses a two-letter prefix inside `[XX …]`. Current components:

| Prefix | Component |
|--------|-----------|
| `YE`   | YAML Editor |
| `DE`   | Dart Editor *(reserved, not yet implemented)* |
| `PE`   | PDF Editor (`tom_pdf_editor`; `PE:js` its pdf.js view) |
| `OE`   | Office Editor (`tom_office_editor`) |
| `ZO`   | ZetaOffice view (`tom_office_zetaoffice`) |
| `FP`   | PDFium editor in Forge (`tom_forge_pdf_pdfium`) |
| `FPJ`  | pdf.js editor in Forge (`tom_forge_pdf_pdfjs`) |
| `FO`   | LibreOfficeKit editor in Forge (`tom_forge_office_lok`) |
| `FZO`  | ZetaOffice editor in Forge (`tom_forge_office_zetaoffice`) |
| `FT`   | External Tools section (`tom_forge_ui`) |

Filter in terminal:
```bash
flutter run 2>&1 | grep '\[YE\]'
```

---

## When to Turn It Off

**Almost never.** The flag exists so you can turn debug mode off for a
production release profile if the console noise becomes unacceptable.
During normal development keep it `true`.

To silence all output without disabling error reporting, comment out the
`debugPrint` line in `trailEvent` rather than flipping the flag — that way
the `try/catch` guards and `FlutterError` intercept stay active even when the
trail is quiet.
