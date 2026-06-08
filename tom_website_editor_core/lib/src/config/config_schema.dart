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
    'content': _contentSpec,
  },
);

/// The per-website `content:` block (§6a). Optional; when present, `dir` is the
/// only required key — the rest fall back to the conventional defaults.
const ObjectSpec _contentSpec = ObjectSpec(
  description: 'Content-browser configuration (§6a). Omit to disable it.',
  required: {'dir'},
  properties: {
    'dir': StringSpec(
        description: 'Root of the content tree (placeholder-expanded).'),
    'components': StringSpec(
        description: 'Glob (relative to dir) for catalog records.'),
    'copy': StringSpec(
        description: 'Glob (relative to dir) for editorial copy files (§16).'),
    'areas': StringSpec(
        description: 'Glob (relative to dir) for area definitions (§17).'),
    'site': StringSpec(description: 'Site-level copy file, relative to dir.'),
    'pages': StringSpec(
        description: 'Glob (relative to dir) for standalone pages.'),
    'editableFields': ListSpec(
      StringSpec(),
      description: 'Curated, hand-editable field names; the rest are managed.',
    ),
    'manualPin': StringSpec(
        description: 'YAML comment that pins a managed field (e.g. "# @manual").'),
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
