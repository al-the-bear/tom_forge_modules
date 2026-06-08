import 'package:yaml/yaml.dart';

import 'content_field.dart';
import 'content_record.dart';

/// Parses a component file's [rawYaml] into a [ContentRecord] tree (§6a):
/// component → `modules:` → optional `submodules:`.
///
/// Field classification uses [editableFields] (curated, hand-editable names) and
/// [manualPin] (the YAML comment that pins a managed field). Pins are detected
/// span-precisely: each key's source line is read from [rawYaml] and checked for
/// the [manualPin] marker, so a `# @manual` on any field — including block
/// scalars and nested module fields — is recognised.
///
/// Throws [YamlException] when [rawYaml] is not a YAML mapping.
ContentRecord parseComponentRecord(
  String rawYaml, {
  required List<String> editableFields,
  required String manualPin,
}) {
  final doc = loadYaml(rawYaml);
  if (doc is! YamlMap) {
    throw YamlException(
        'content record must be a YAML mapping', doc is YamlNode ? doc.span : null);
  }
  final lines = rawYaml.split('\n');
  return _buildRecord(
    doc,
    ContentRecordKind.component,
    lines,
    editableFields.toSet(),
    manualPin,
    0,
  );
}

/// The child list key for each record level (`modules` under a component,
/// `submodules` under a module; submodules have no children).
String? _childKey(ContentRecordKind kind) => switch (kind) {
      ContentRecordKind.component => 'modules',
      ContentRecordKind.module => 'submodules',
      ContentRecordKind.submodule => null,
    };

ContentRecordKind _childKind(ContentRecordKind kind) => switch (kind) {
      ContentRecordKind.component => ContentRecordKind.module,
      ContentRecordKind.module => ContentRecordKind.submodule,
      ContentRecordKind.submodule => ContentRecordKind.submodule,
    };

ContentRecord _buildRecord(
  YamlMap map,
  ContentRecordKind kind,
  List<String> lines,
  Set<String> editableFields,
  String manualPin,
  int index,
) {
  final childKey = _childKey(kind);
  final fields = <ContentField>[];
  final children = <ContentRecord>[];

  for (final entry in map.nodes.entries) {
    final keyNode = entry.key as YamlNode;
    final name = keyNode.value.toString();
    final valueNode = entry.value;

    if (name == childKey && valueNode is YamlList) {
      var childIndex = 0;
      for (final item in valueNode.nodes) {
        if (item is YamlMap) {
          children.add(_buildRecord(item, _childKind(kind), lines,
              editableFields, manualPin, childIndex));
          childIndex++;
        }
      }
      continue;
    }

    final line = keyNode.span.start.line;
    final pinned = line < lines.length && lines[line].contains(manualPin);
    fields.add(ContentField(
      name: name,
      value: _stringify(valueNode),
      isEditable: editableFields.contains(name) || pinned,
      isPinned: pinned,
      sourceLine: line,
    ));
  }

  return ContentRecord(
    kind: kind,
    id: map['id']?.toString() ?? '$kind[$index]',
    name: map['name']?.toString(),
    fields: fields,
    children: children,
  );
}

/// Renders a field value for display: scalars as text, flow lists comma-joined,
/// anything else via its parsed value.
String _stringify(YamlNode node) {
  final value = node.value;
  if (value is List) return value.join(', ');
  return value?.toString() ?? '';
}

/// Returns [rawYaml] with the [manualPin] appended to the field whose key is on
/// [sourceLine] (0-based), unless the pin is already present. Used when the user
/// pins a managed field so the edit survives the next regenerate (§6a).
String pinFieldLine(String rawYaml, int sourceLine, String manualPin) {
  final lines = rawYaml.split('\n');
  if (sourceLine < 0 || sourceLine >= lines.length) return rawYaml;
  final line = lines[sourceLine];
  if (line.contains(manualPin)) return rawYaml;
  lines[sourceLine] = '${line.trimRight()}  $manualPin';
  return lines.join('\n');
}

/// Returns [rawYaml] with the scalar value of the field on [sourceLine]
/// (0-based) replaced by [value], used by the §6a inline editor to persist a
/// curated scalar edit.
///
/// Preserves the line's indentation and its `key:`; when [preserveComment] is a
/// trailing comment on that line (e.g. the manual pin) it is re-appended so a
/// pinned field stays pinned. The new value is double-quoted only when bare YAML
/// would be ambiguous (empty, leading/trailing space, or a YAML-special
/// character), so simple words stay unquoted.
String setFieldLineValue(
  String rawYaml,
  int sourceLine,
  String value, {
  String? preserveComment,
}) {
  final lines = rawYaml.split('\n');
  if (sourceLine < 0 || sourceLine >= lines.length) return rawYaml;
  final line = lines[sourceLine];
  final colon = line.indexOf(':');
  if (colon < 0) return rawYaml;

  final keyPart = line.substring(0, colon + 1);
  final comment = (preserveComment != null &&
          line.indexOf(preserveComment, colon + 1) > colon)
      ? '  $preserveComment'
      : '';
  lines[sourceLine] = '$keyPart ${_encodeScalar(value)}$comment';
  return lines.join('\n');
}

/// Renders [value] as a YAML flow scalar, quoting only when a bare scalar would
/// be misread.
String _encodeScalar(String value) {
  if (value.isEmpty) return '""';
  final needsQuote = value != value.trim() ||
      value.contains(RegExp(r'[:#]')) ||
      RegExp(r'^[!&*\[\]{}>|@`"' "'" r'%-]').hasMatch(value);
  if (!needsQuote) return value;
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}
