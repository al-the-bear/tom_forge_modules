# How to Embed `tom_yaml_editor` with `tom_dart_editor`

This guide shows the simplest way to use Dart code editing inside YAML fields (for example keys ending in `-dart`).

## 1) Register a Dart suffix editor

```dart
import 'package:flutter/material.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

EditorSuffix dartSuffixEditor() {
  return EditorSuffix(
    suffix: 'dart',
    label: 'Dart Code',
    icon: Icons.code,
    supportsPopout: true,
    popoutTitle: 'Dart Editor',
    factory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return SimpleSummaryBackedDartCodeEditor(
        initialCode: value as String? ?? '',
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: 'assets/summaries/dart-editor/packages.sum',
        readOnly: readOnly,
        settings: const DartEditorSettings(
          showToolbar: false,
          showLineNumbers: false,
          showAutoCompleteToggle: false,
          showErrorToggles: false,
          showWarningToggles: false,
          showInfoToggles: false,
          showPopupPositionToggle: false,
          showOpenReferenceButton: false,
        ),
        onChanged: (code) => onChanged(code),
      );
    },
    popoutFactory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return SimpleSummaryBackedDartCodeEditor(
        initialCode: value as String? ?? '',
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: 'assets/summaries/dart-editor/packages.sum',
        readOnly: readOnly,
        onChanged: (code) => onChanged(code),
      );
    },
  );
}
```

## 2) Build registry and embed YAML editor

```dart
final registry = EditorRegistry.defaults().register(dartSuffixEditor());

SimpleYamlSchemaEditor(
  initialYaml: '''
script-dart: |
  void main() {
    print('hello');
  }
''',
  schemaJson: {
    'type': 'object',
    'properties': {
      'script-dart': {'type': 'string'}
    }
  },
  editorRegistry: registry,
)
```

## 3) Asset requirements

Dart analyzer-backed editing requires the summary pair in the host app, as
`tom_dart_editor_bundler` lays it out (`tom_dart_editor/doc/package_summary_generation.md`;
the Forge apps copy the pair built in `tom_dart_editor_test`):

- `assets/summaries/sdk_summary.sum`
- `assets/summaries/dart-editor/packages.sum`

And in host `pubspec.yaml` (asset directory entries are not recursive):

```yaml
flutter:
  assets:
    - assets/summaries/
    - assets/summaries/dart-editor/
```

## Result

- YAML embedding stays simple (`SimpleYamlSchemaEditor`).
- Dart integration stays simple (`SimpleSummaryBackedDartCodeEditor`).
- Full customization remains available when needed.
