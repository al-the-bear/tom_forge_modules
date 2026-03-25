import 'package:tom_forge_core/tom_forge_core.dart';

import 'forge_editor.dart';

/// A schema-aware editor that uses content inspection for file handling.
///
/// Always returns [FileHandlingResult.inspect] from [canHandle] and
/// relies on [canHandleContent] to detect schema compatibility.
abstract class ForgeSchemaEditor extends ForgeEditor {
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.inspect;

  @override
  FileHandlingResult canHandleContent(Uri uri, List<int> bytes);

  /// The schema identifier shown in "Open with" dialog.
  String get schemaLabel;
}
