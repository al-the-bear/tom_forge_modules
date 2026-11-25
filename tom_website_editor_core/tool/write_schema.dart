// Regenerates the committed JSON Schema for `tom.website-editor.yaml` from the
// field-spec model (the single source of truth) into the Tom root's
// `.tom/json-schema/website-editor/`. Run from the package root:
//
//   dart run tool/write_schema.dart
//
// The TWEC-SCH-08 test fails if the committed file drifts from this output.
import 'dart:io';

import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import 'schema_location.dart';

void main() {
  // The Tom root's `.tom/json-schema/website-editor/` (schema_location.dart).
  final file = committedWebsiteEditorSchema();
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(websiteEditorJsonSchemaString());
  stdout.writeln('Wrote ${file.path}');
}
