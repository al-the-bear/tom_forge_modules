import 'package:yaml/yaml.dart';

import 'content_field.dart';
import 'content_group.dart';
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
  final groups = <ContentGroup>[];
  String? provenance;
  String? generatedSource;

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

    // The component's `groups:` block (§9 item 1) is hand-authored structured
    // data — editable, never generator-owned — surfaced as [ContentRecord.groups]
    // rather than a flat field. It is parsed only at the component level.
    if (name == _groupsKey &&
        kind == ContentRecordKind.component &&
        valueNode is YamlList) {
      groups.addAll(_parseGroups(valueNode));
      continue;
    }

    // The `_generated` block is generator provenance, not a content field: it
    // is captured as the record's [provenance] and never rendered inline.
    if (name == _provenanceKey) {
      provenance = _provenanceOf(valueNode);
      // `_generated.source` is the component's repo root (relative to the
      // website's sourceRoot); kept so repo-sourced docs can be resolved (§9
      // item 5). The one-line [provenance] still carries it for display.
      if (valueNode is YamlMap) {
        final src = valueNode['source'];
        if (src is String && src.isNotEmpty) generatedSource = src;
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

  // A component's repo root comes from `_generated.source`; a module's /
  // submodule's from its `path` field. This unifies how repo-sourced docs (§9
  // item 5) are located for any record.
  var source = generatedSource;
  if (source == null) {
    for (final field in fields) {
      if (field.name == 'path' && field.value.isNotEmpty) {
        source = field.value;
        break;
      }
    }
  }

  return ContentRecord(
    kind: kind,
    id: map['id']?.toString() ?? '$kind[$index]',
    name: map['name']?.toString(),
    fields: fields,
    children: children,
    groups: groups,
    provenance: provenance,
    source: source,
  );
}

/// The component-level key holding the hand-authored module groups (§9 item 1).
const String _groupsKey = 'groups';

/// Parses a `groups:` [list] node into [ContentGroup]s. Each item is a mapping
/// with a `label` scalar and a `members` list of module ids; absent keys yield
/// an empty label / empty member list so a partially-authored block still loads.
List<ContentGroup> _parseGroups(YamlList list) {
  final groups = <ContentGroup>[];
  for (final item in list.nodes) {
    if (item is! YamlMap) continue;
    final label = item['label']?.toString() ?? '';
    final membersNode = item.nodes['members'];
    final members = <String>[
      if (membersNode is YamlList)
        for (final m in membersNode.nodes) m.value.toString(),
    ];
    groups.add(ContentGroup(label: label, members: members));
  }
  return groups;
}

/// The reserved key holding a record's generator provenance (§6a).
const String _provenanceKey = '_generated';

/// Renders a record's `_generated` [node] as a one-line provenance string. A
/// mapping becomes `key: value · key: value` (document order); a scalar becomes
/// its text. Returns `null` for an empty block so the UI shows no badge.
String? _provenanceOf(YamlNode node) {
  if (node is YamlMap) {
    final parts = [
      for (final entry in node.nodes.entries)
        '${(entry.key as YamlNode).value}: ${entry.value.value}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
  final value = node.value?.toString();
  return (value == null || value.isEmpty) ? null : value;
}

/// Renders a field value for display: scalars as text, flow lists comma-joined,
/// anything else via its parsed value.
String _stringify(YamlNode node) => stringifyContentValue(node.value);

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

/// Returns [rawYaml] with the [manualPin] marker removed from the field whose
/// key is on [sourceLine] (0-based), reverting a pinned field to generator-
/// managed status. The inverse of [pinFieldLine]: the trailing marker (and the
/// whitespace that separated it from the value) is stripped, so the next
/// regenerate is free to overwrite the field's value again (§6a).
///
/// Returns [rawYaml] unchanged when the line is out of range or carries no pin.
String unpinFieldLine(String rawYaml, int sourceLine, String manualPin) {
  final lines = rawYaml.split('\n');
  if (sourceLine < 0 || sourceLine >= lines.length) return rawYaml;
  final line = lines[sourceLine];
  final markerAt = line.indexOf(manualPin);
  if (markerAt < 0) return rawYaml;
  lines[sourceLine] = line.substring(0, markerAt).trimRight();
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

/// Returns [rawYaml] with the value of the field on [sourceLine] (0-based)
/// cleared, leaving a bare `key:` (no value) so the line reads as an empty
/// optional. Preserves the line's indentation and key; a no-op when the line is
/// out of range or has no `:`. Used to set an optional scalar (e.g.
/// `home.featured`) back to "unset" without writing an empty-string literal.
String clearFieldLineValue(String rawYaml, int sourceLine) {
  final lines = rawYaml.split('\n');
  if (sourceLine < 0 || sourceLine >= lines.length) return rawYaml;
  final line = lines[sourceLine];
  final colon = line.indexOf(':');
  if (colon < 0) return rawYaml;
  lines[sourceLine] = line.substring(0, colon + 1);
  return lines.join('\n');
}

/// Returns [rawYaml] with its component-level `groups:` block replaced by a
/// canonical serialization of [groups] (§9 item 1), preserving every other line.
///
/// Behaviour:
/// - When [groups] is empty, the existing `groups:` block is removed (and the
///   source returned unchanged if there was none).
/// - When the document already has a `groups:` block, it is replaced in place.
/// - When it has none, the new block is inserted **before** `modules:` (the
///   generator-owned list), falling back to before `_generated:` and finally to
///   the end of the document, so the hand-authored block reads ahead of the
///   mechanical fields.
///
/// The serialization is canonical and stable: re-writing a document's own parsed
/// groups is a no-op, so the block round-trips unchanged across a regenerate
/// (the generator owns only `[id, name, category, modules]` and never the
/// groups block).
String setComponentGroups(String rawYaml, List<ContentGroup> groups) {
  final lines = rawYaml.split('\n');
  final start = _topLevelKeyLine(lines, _groupsKey);
  final block = _serializeGroups(groups);

  if (start == null) {
    if (block.isEmpty) return rawYaml;
    final insertAt = _topLevelKeyLine(lines, 'modules') ??
        _topLevelKeyLine(lines, _provenanceKey) ??
        _appendIndex(lines);
    lines.insertAll(insertAt, block);
    return lines.join('\n');
  }

  final end = _blockEnd(lines, start);
  lines.replaceRange(start, end, block);
  return lines.join('\n');
}

/// The index of the first top-level (column-0) line whose key is [key], or
/// `null` when the document has no such key. Comment and indented lines never
/// match, so a nested `members:` is not mistaken for a top-level key.
int? _topLevelKeyLine(List<String> lines, String key) {
  final pattern = RegExp('^${RegExp.escape(key)}:(\\s|\$)');
  for (var i = 0; i < lines.length; i++) {
    if (pattern.hasMatch(lines[i])) return i;
  }
  return null;
}

/// The index just past the last content line of the block starting at [start]
/// (a top-level key). Indented and blank lines belong to the block; the scan
/// stops at the next top-level key. Trailing blank lines are excluded so a blank
/// separator before the following key is preserved.
int _blockEnd(List<String> lines, int start) {
  var lastContent = start;
  var i = start + 1;
  while (i < lines.length) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      i++;
      continue;
    }
    if (line.startsWith(' ') || line.startsWith('\t')) {
      lastContent = i;
      i++;
      continue;
    }
    break; // a following top-level key
  }
  return lastContent + 1;
}

/// The insertion index for appending a block at the document end, before any
/// trailing blank line produced by a final newline so the block stays contiguous.
int _appendIndex(List<String> lines) {
  var i = lines.length;
  while (i > 0 && lines[i - 1].trim().isEmpty) {
    i--;
  }
  return i;
}

/// Renders [groups] as the canonical lines of a `groups:` block (§9 item 1):
/// each group is a `- label:` item with a flow-list `members: [a, b]`. Returns
/// an empty list for no groups (the caller removes the block).
List<String> _serializeGroups(List<ContentGroup> groups) {
  if (groups.isEmpty) return const [];
  final out = <String>['$_groupsKey:'];
  for (final group in groups) {
    out.add('  - label: ${_encodeScalar(group.label)}');
    final members = group.members.map(_encodeScalar).join(', ');
    out.add('    members: [$members]');
  }
  return out;
}

/// The top-level key holding the editable detailed-content scope (editor §9
/// item 7): the component ids whose `/docs` + `/api` trees the site exposes.
const String _detailedComponentsKey = 'detailedComponents';

/// Returns [rawYaml] with the top-level `detailedComponents:` key set to a flow
/// list of [ids] (editor §9 item 7).
///
/// Unlike [setFieldLineValue], this writes a YAML **list** (`[a, b]`) rather
/// than a quoted scalar, so the value round-trips as a list. When the key
/// already exists its 0-based [sourceLine] is given and the line is replaced in
/// place (preserving a trailing comment); when [sourceLine] is `null` the key is
/// inserted **before** `home:` — falling back to before `_generated:` and then
/// the document end — so the editable scope reads near the other site-level
/// fields rather than after the mechanical block.
///
/// An empty [ids] writes an explicit empty list (`[]`), which the website reads
/// as "no detailed components" (distinct from removing the key, which falls back
/// to the built-in default).
String setDetailedComponentsLine(
  String rawYaml,
  int? sourceLine,
  List<String> ids,
) {
  final lines = rawYaml.split('\n');
  final encoded = '$_detailedComponentsKey: ${_encodeFlowList(ids)}';

  if (sourceLine != null && sourceLine >= 0 && sourceLine < lines.length) {
    final comment = _trailingComment(lines[sourceLine]);
    lines[sourceLine] = comment.isEmpty ? encoded : '$encoded  $comment';
    return lines.join('\n');
  }

  final insertAt = _topLevelKeyLine(lines, 'home') ??
      _topLevelKeyLine(lines, _provenanceKey) ??
      _appendIndex(lines);
  lines.insert(insertAt, encoded);
  return lines.join('\n');
}

/// Renders [ids] as a YAML flow list (`[a, b]`), quoting each id only when a
/// bare scalar would be misread.
String _encodeFlowList(List<String> ids) =>
    '[${ids.map(_encodeScalar).join(', ')}]';

/// Extracts a trailing YAML comment from [line] (a `#` preceded by whitespace,
/// to its end), or `''` when there is none. Component ids never contain `#`, so
/// the first whitespace-prefixed `#` after the flow list is the comment.
String _trailingComment(String line) {
  final match = RegExp(r'\s(#.*)$').firstMatch(line);
  return match == null ? '' : match.group(1)!;
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
