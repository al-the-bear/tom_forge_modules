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
  /// - `form` types: generates `Key: ` lines for each form field
  /// - `code` types: generates a fenced code block with the first language
  /// - default: returns the type description as placeholder text
  String generateTemplate(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return '';

    final format = typeDef.format;
    if (format != null) {
      // Check for form format (e.g., "form endpoint-form")
      if (format.startsWith('form ')) {
        final formTypeName = format.substring(5).trim();
        return _buildFormTemplate(formTypeName, typeDef);
      }
      // Check for code format (e.g., "code dart|typescript|python")
      if (format.startsWith('code ')) {
        final languages = format.substring(5).trim();
        return _buildCodeTemplate(languages);
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

  /// Get the text pattern regex for a section type, if defined.
  String? getTextPattern(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    return typeDef?.patternCheckText?.pattern;
  }

  /// Get the allowed code languages for a code-format section.
  List<String> getCodeLanguages(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return const [];
    final format = typeDef.format;
    if (format == null || !format.startsWith('code ')) return const [];
    return format.substring(5).trim().split('|');
  }

  /// Get the form type definition for a form-format section.
  specs.FormTypeDef? getFormType(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return null;
    final format = typeDef.format;
    if (format == null || !format.startsWith('form ')) return null;
    final formTypeName = format.substring(5).trim();
    return schema.formTypes?[formTypeName];
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
  String _buildCodeTemplate(String languages) {
    final firstLang = languages.split('|').first.trim();
    return '```$firstLang\n// TODO: Add code here\n```';
  }

  /// Build template from description.
  String _buildDescriptionTemplate(specs.SectionTypeDef typeDef) {
    if (typeDef.description != null && typeDef.description!.isNotEmpty) {
      return '<!-- ${typeDef.description} -->';
    }
    return '';
  }
}
