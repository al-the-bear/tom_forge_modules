import 'package:flutter/foundation.dart';
import 'package:tom_doc_scanner/tom_doc_scanner.dart' as scanner;
import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../debug/md_editor_debug.dart';
import '../models/md_document.dart';
import '../models/md_section.dart';

/// Adapts tom_doc_specs schema validation for the markdown editor.
///
/// Converts between the editor's [MdDocument]/[MdSection] models and
/// tom_doc_scanner's [scanner.Document]/[scanner.Section] models,
/// then delegates to [specs.DocSpecsValidator] for validation.
class MdSchemaValidator {
  /// The currently loaded schema.
  specs.DocSpecSchema? _schema;

  /// The current schema, if any.
  specs.DocSpecSchema? get schema => _schema;

  /// Whether a schema is loaded and validation is available.
  bool get hasSchema => _schema != null;

  /// The current schema ID, if any.
  String? get schemaId => _schema?.fullId;

  /// Set the schema to validate against.
  void setSchema(specs.DocSpecSchema schema) {
    _schema = schema;
  }

  /// Clear the current schema.
  void clearSchema() {
    _schema = null;
  }

  /// Validate an [MdDocument] against the loaded schema.
  ///
  /// Returns an empty list if no schema is loaded.
  List<ValidationError> validate(MdDocument mdDocument) {
    if (_schema == null) return const [];

    try {
      final document = _convertDocument(mdDocument);
      final validator = specs.DocSpecsValidator(schema: _schema!);
      final specErrors = validator.validate(document);

      // Log validation errors to console for debugging
      if (specErrors.isNotEmpty) {
        debugPrint(
            '[MdSchemaValidator] ${specErrors.length} validation error(s):');
        for (final e in specErrors) {
          debugPrint(
              '  [${e.category.name}] ${e.message} '
              '(line ${e.lineNumber}, section: ${e.sectionId})');
        }
      } else {
        debugPrint('[MdSchemaValidator] Document passed validation');
      }

      return specErrors.map(_convertError).toList();
    } catch (e, st) {
      MdEditorDebug.logger.error('Schema validation failed', e, st);
      return [
        ValidationError(
          path: const ['schema'],
          message: 'Schema validation error: $e',
          severity: ValidationSeverity.warning,
        ),
      ];
    }
  }

  /// Convert an [MdDocument] to a doc_scanner [scanner.Document].
  scanner.Document _convertDocument(MdDocument mdDocument) {
    final sections = mdDocument.sections
        .map((s) => _convertSection(s, 0))
        .toList();

    return scanner.Document(
      index: 0,
      lineNumber: 1,
      name: mdDocument.title ?? '',
      id: mdDocument.title ?? 'document',
      rawHeadline: '',
      fields: _extractDocumentFields(mdDocument),
      text: '',
      sections: sections.isEmpty ? null : sections,
      filenameWithPath: mdDocument.path ?? '',
      loadTimestamp: DateTime.now().toIso8601String(),
      filename: _extractFilename(mdDocument.path),
      fullPath: '',
      workspacePath: '',
      project: '',
      projectPath: '',
      workspaceRoot: '',
      projectRoot: '',
      hierarchyDepth: _calculateMaxDepth(mdDocument.sections),
    );
  }

  /// Convert an [MdSection] to a doc_scanner [scanner.Section].
  scanner.Section _convertSection(MdSection mdSection, int index) {
    final subsections = mdSection.subsections
        .asMap()
        .entries
        .map((e) => _convertSection(e.value, e.key))
        .toList();

    return scanner.Section(
      index: index,
      lineNumber: mdSection.sourceLineStart ?? 0,
      name: mdSection.headline,
      id: mdSection.id ?? '',
      rawHeadline: '${'#' * mdSection.level} ${mdSection.headline}',
      fields: const {},
      text: mdSection.text,
      sections: subsections.isEmpty ? null : subsections,
    );
  }

  /// Convert a doc_specs [specs.ValidationError] to an editor
  /// [ValidationError].
  ValidationError _convertError(specs.ValidationError specError) {
    final path = <Object>[];
    if (specError.sectionId != null) {
      path.add(specError.sectionId!);
    }
    path.add(specError.category.name);

    return ValidationError(
      path: path,
      message: specError.message,
      severity: _mapCategory(specError.category),
      code: specError.category.name,
    );
  }

  /// Map doc_specs error categories to editor severity levels.
  ValidationSeverity _mapCategory(specs.ValidationErrorCategory category) {
    return switch (category) {
      specs.ValidationErrorCategory.schemaDeclaration =>
        ValidationSeverity.info,
      specs.ValidationErrorCategory.structure => ValidationSeverity.error,
      specs.ValidationErrorCategory.countLimit => ValidationSeverity.warning,
      specs.ValidationErrorCategory.nestingDepth => ValidationSeverity.warning,
      specs.ValidationErrorCategory.sectionId => ValidationSeverity.error,
      _ => ValidationSeverity.warning,
    };
  }

  /// Extract document-level fields (e.g., schema declaration).
  Map<String, String> _extractDocumentFields(MdDocument mdDocument) {
    final fields = <String, String>{};
    if (mdDocument.schemaId != null) {
      fields['schema'] = mdDocument.schemaId!;
    }
    return fields;
  }

  /// Extract filename from a path string.
  String _extractFilename(String? path) {
    if (path == null || path.isEmpty) return '';
    final lastSlash = path.lastIndexOf('/');
    return lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  }

  /// Calculate the maximum heading depth in the section tree.
  int _calculateMaxDepth(List<MdSection> sections) {
    if (sections.isEmpty) return 0;
    var maxDepth = 0;
    for (final section in sections) {
      final depth = section.level;
      final subDepth = _calculateMaxDepth(section.subsections);
      maxDepth = depth > maxDepth ? depth : maxDepth;
      if (subDepth > maxDepth) maxDepth = subDepth;
    }
    return maxDepth;
  }
}
