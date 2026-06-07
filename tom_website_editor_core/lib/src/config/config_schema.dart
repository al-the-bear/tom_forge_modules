import 'dart:convert';

import 'field_spec.dart';

/// `$id` of the published JSON Schema (matches the committed file name).
const String websiteEditorSchemaId = 'tom.website-editor.schema.json';

/// The single declarative description of a `tom.website-editor.yaml` document.
///
/// Both the runtime validator and the JSON Schema are derived from this tree
/// (§6 "single source of truth"). See §2–§3 of the specification.
final ObjectSpec websiteEditorConfigSpec = ObjectSpec(
  description: 'Registry of websites the tom_website_editor can drive.',
  required: {'version', 'websites'},
  properties: {
    'version': const IntSpec(
      constValue: 1,
      description: 'Config format version (currently 1).',
    ),
    'defaults': const ObjectSpec(
      description: 'Defaults shared by every website entry.',
      properties: {
        'shell': ListSpec(
          StringSpec(),
          description: 'argv prefix used to execute command templates.',
        ),
        'placeholders': MapSpec(
          StringSpec(),
          description: 'Workspace-wide placeholder values (§3).',
        ),
      },
    ),
    'websites': ListSpec(
      _websiteSpec,
      minItems: 1,
      description: 'The registered websites (at least one).',
    ),
  },
);

const ObjectSpec _websiteSpec = ObjectSpec(
  description: 'One drivable website.',
  required: {'id', 'paths'},
  properties: {
    'id': StringSpec(description: 'Unique website identifier.'),
    'label': StringSpec(description: 'Human-readable label for the selector.'),
    'paths': ObjectSpec(
      description: 'Filesystem locations (placeholder-expanded).',
      required: {'websiteRoot'},
      properties: {
        'websiteRoot': StringSpec(description: 'Command working directory.'),
        'designDir': StringSpec(),
        'sourceRoot': StringSpec(),
        'builtDir': StringSpec(),
      },
      additionalProperties: StringSpec(),
    ),
    'preview': ObjectSpec(
      description: 'Preview URLs (placeholder-expanded).',
      properties: {
        'devUrl': StringSpec(),
        'builtIndex': StringSpec(),
      },
      additionalProperties: StringSpec(),
    ),
    'cwd': StringSpec(
        description: 'Working directory for commands (defaults to websiteRoot).'),
    'commands': MapSpec(
      StringSpec(),
      description: 'Action name → external command template (§7 contract).',
    ),
    // §6a content block — kept optional and lenient until that step pins it.
    'content': AnySpec(
        description: 'Optional content-browser configuration (§6a).'),
  },
);

/// Returns the JSON Schema (draft-07) for `tom.website-editor.yaml`, generated
/// from [websiteEditorConfigSpec].
Map<String, dynamic> websiteEditorJsonSchema() => {
      r'$schema': 'http://json-schema.org/draft-07/schema#',
      r'$id': websiteEditorSchemaId,
      'title': 'tom.website-editor.yaml',
      ...websiteEditorConfigSpec.toJsonSchema(),
    };

/// The canonical pretty-printed JSON for the committed schema file
/// (two-space indent, trailing newline).
String websiteEditorJsonSchemaString() =>
    '${const JsonEncoder.withIndent('  ').convert(websiteEditorJsonSchema())}\n';
