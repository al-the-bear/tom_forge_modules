// Regenerates the committed JSON Schema for `tom.website-editor.yaml` from the
// field-spec model (the single source of truth). Run from the package root:
//
//   dart run tool/write_schema.dart
//
// The TWEC-SCH-08 test fails if the committed file drifts from this output.
import 'dart:io';

import 'package:tom_website_editor_core/tom_website_editor_core.dart';

/// Committed schema location, relative to the package root.
const _committedSchemaPath =
    '../../.tom/json-schema/website-editor/tom.website-editor.schema.json';

void main() {
  final file = File(_committedSchemaPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(websiteEditorJsonSchemaString());
  stdout.writeln('Wrote ${file.path}');
}
