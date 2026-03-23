import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;

/// Generates section templates from DocSpecs schema definitions.
///
/// Used by the editor to pre-fill content when inserting new sections
/// based on their schema type, including form fields, code blocks,
/// and description-based placeholder text.
class SchemaTemplateHelper {
  final specs.DocSpecSchema schema;

  SchemaTemplateHelper(this.schema);

  /// Generate template text for a section of the given type.
  ///
  /// Returns pre-filled content based on the type's format:
  /// - form types (ending in `-form`): generates `Key: ` lines for each field
  /// - code types (pipe-separated languages or single language): fenced block
  /// - default: returns the type description as placeholder text
  String generateTemplate(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return '';

    final format = typeDef.format;
    if (format != null) {
      // Check for form format (e.g., "endpoint-form")
      if (format.endsWith('-form')) {
        return _buildFormTemplate(format, typeDef);
      }
      // Code format: single language or pipe-separated list
      // (e.g., "sql" or "dart|typescript|python")
      if (_looksLikeCodeFormat(format)) {
        final firstLang = format.split('|').first.trim();
        return _buildCodeTemplate(firstLang);
      }
    }

    return _buildDescriptionTemplate(typeDef);
  }

  /// Generate a headline for the given type, suitable for new sections.
  String generateHeadline(String typeName) {
    return typeName
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Generate a suggested ID based on the type's prefix and pattern.
  String? generateSuggestedId(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return null;
    return typeDef.prefix;
  }

  /// Get the ID pattern regex for a section type, if defined.
  String? getIdPattern(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    return typeDef?.patternCheckId?.pattern;
  }

  /// Get the ID pattern info (pattern + error message) for a section type.
  ({String pattern, String errorMessage})? getIdPatternInfo(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    final check = typeDef?.patternCheckId;
    if (check == null) return null;
    return (pattern: check.pattern, errorMessage: check.errorMessage);
  }

  /// Get the text pattern regex for a section type, if defined.
  String? getTextPattern(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    return typeDef?.patternCheckText?.pattern;
  }

  /// Get the allowed code languages for a code-format section.
  ///
  /// Format syntax per docspecs spec: pipe-separated language names
  /// (e.g., `dart|typescript|python`) or a single language (e.g., `sql`).
  List<String> getCodeLanguages(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return const [];
    final format = typeDef.format;
    if (format == null || !_looksLikeCodeFormat(format)) return const [];
    return format.split('|').map((l) => l.trim()).toList();
  }

  /// Get the form type definition for a form-format section.
  ///
  /// Format syntax per docspecs spec: name ending in `-form`
  /// (e.g., `endpoint-form`). The form type name IS the format value.
  specs.FormTypeDef? getFormType(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return null;
    final format = typeDef.format;
    if (format == null || !format.endsWith('-form')) return null;
    return schema.formTypes?[format];
  }

  /// Get the allowed tags for a section type.
  List<String> getAllowedTags(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    return typeDef?.allowedTags ?? const [];
  }

  /// Get text length constraints for a section type.
  ({int? min, int? max, bool required}) getTextConstraints(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) {
      return (min: null, max: null, required: false);
    }
    return (
      min: typeDef.minTextLength,
      max: typeDef.maxTextLength,
      required: typeDef.textRequired ?? false,
    );
  }

  /// Get the validation prompt for a section type.
  String? getValidationPrompt(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    return typeDef?.validationPrompt;
  }

  /// Get the validation prompt for a section, checking document-level
  /// overrides first, then falling back to the section-type prompt.
  ///
  /// Document sections can define their own `validation-prompt` that
  /// overrides the type-level prompt. This method also checks for
  /// `subsection-validation-prompt` on parent document sections.
  String? getDocumentValidationPrompt({
    required String typeName,
    String? sectionId,
    String? parentSectionId,
  }) {
    // Check document-level section overrides.
    for (final entry in schema.document.sections.entries) {
      // Match by section type.
      if (entry.value.sectionType == typeName) {
        if (entry.value.validationPrompt != null) {
          return entry.value.validationPrompt;
        }
      }
      // Check if this section is a child — use parent's subsectionValidationPrompt.
      if (parentSectionId != null &&
          entry.value.subsectionValidationPrompt != null) {
        final parentType = schema.sectionTypes[entry.value.sectionType];
        if (parentType?.prefix != null &&
            parentSectionId.startsWith(parentType!.prefix!)) {
          return entry.value.subsectionValidationPrompt;
        }
      }
    }

    // Fall back to type-level prompt.
    return schema.sectionTypes[typeName]?.validationPrompt;
  }

  /// Get the required fields for a section type.
  List<String> getRequiredFields(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    return typeDef?.requiredFields ?? const [];
  }

  /// Build template for form-format sections.
  String _buildFormTemplate(String formTypeName, specs.SectionTypeDef typeDef) {
    final formType = schema.formTypes?[formTypeName];
    if (formType == null) {
      return typeDef.description ?? '';
    }

    final buffer = StringBuffer();
    for (final field in formType.fields) {
      final marker = (field.required ?? false) ? ' (required)' : '';
      buffer.writeln('- ${field.fieldname}:$marker');
    }
    return buffer.toString().trimRight();
  }

  /// Build template for code-format sections.
  String _buildCodeTemplate(String language) {
    return '```$language\n// TODO: Add code here\n```';
  }

  /// Whether a format string looks like a code language specification.
  ///
  /// Code formats are either a single lowercase word (e.g., `sql`, `dart`)
  /// or pipe-separated lowercase words (e.g., `dart|typescript|python`).
  /// Excludes form formats (ending in `-form`).
  static bool _looksLikeCodeFormat(String format) {
    if (format.endsWith('-form')) return false;
    // Must be non-empty and composed of word characters, pipes, and dashes.
    return RegExp(r'^[a-z][a-z0-9]*([|][a-z][a-z0-9]*)*$').hasMatch(format);
  }

  /// Build template from description.
  String _buildDescriptionTemplate(specs.SectionTypeDef typeDef) {
    if (typeDef.description != null && typeDef.description!.isNotEmpty) {
      return '<!-- ${typeDef.description} -->';
    }
    return '';
  }
}
