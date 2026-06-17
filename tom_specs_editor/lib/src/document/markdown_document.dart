import '../structure/spec_model.dart';
import 'spec_document_controller.dart';

/// The scope of a markdown import/export (§15.2): one root projection, a subset
/// of roots, or the Project Definition master.
enum MarkdownScope { single, multiple, global }

/// Why an imported markdown block was rejected (§15.2 parse-rejection protocol).
enum MarkdownRejectReason {
  /// The heading's section path does not resolve against the model.
  unknownSection,

  /// A value anchor sat under a heading of the wrong kind (e.g. a form-field
  /// anchor under a content section, or a content body under a list/section).
  kindMismatch,

  /// A fenced value block had no owning section/field to attach to.
  orphanBlock,

  /// A content/form anchor was opened but no fenced value followed it.
  missingValue,

  /// A heading line carried no parseable section path.
  malformedHeading,
}

/// One rejected block in a markdown import (§15.2). Reported, never silently
/// dropped: each carries the source [line], the offending [anchor] (section
/// path or field name), the [reason], and a human-readable [message].
class MarkdownRejection {
  MarkdownRejection({
    required this.line,
    required this.reason,
    required this.message,
    this.anchor,
  });

  final int line;
  final MarkdownRejectReason reason;
  final String message;
  final String? anchor;

  @override
  String toString() =>
      'line $line: ${reason.name}${anchor != null ? ' ($anchor)' : ''} — '
      '$message';
}

/// The outcome of parsing a markdown document (§15.2): the staged values plus
/// every rejected block. The values are keyed exactly like
/// [SpecDocument.toJson] so the controller can merge them into the live
/// document as a full overwrite of the covered scope.
class MarkdownImportResult {
  MarkdownImportResult({
    required this.content,
    required this.forms,
    required this.lists,
    required this.rejections,
    required this.rootPrefixes,
  });

  /// Content/scalar/enum leaf values: section path → value.
  final Map<String, String> content;

  /// Form values: form path → (field name → value).
  final Map<String, Map<String, String>> forms;

  /// List membership: list path → `{seq, items}` (the [SpecDocument.toJson]
  /// shape), reconstructed from the `-N` item segments of the leaf paths.
  final Map<String, Map<String, Object?>> lists;

  /// Every rejected block, in source order.
  final List<MarkdownRejection> rejections;

  /// The root segment(s) the import covers (the first segment of each accepted
  /// path) — the scope a full-overwrite apply purges before writing.
  final Set<String> rootPrefixes;

  /// Whether the parse was clean (no rejections).
  bool get isClean => rejections.isEmpty;

  /// The number of leaf values successfully parsed (content + form fields).
  int get appliedCount =>
      content.length + forms.values.fold<int>(0, (a, m) => a + m.length);
}

/// Codec for the markdown import/export format (§15.2).
///
/// The format is the markdown analogue of the native `*.docspecs.yaml`
/// (§15.1): a `<!-- docspec: -->` header, then one heading per **populated**
/// section (sparse, in schema order), with each section's machine-readable
/// **section path** as the first token of its heading so import maps back
/// unambiguously. Leaf values live in **fenced code blocks** whose fence is
/// widened past any backtick run in the value — the markdown equivalent of
/// §15.1's all-block-scalar discipline — so embedded d4rt-flutter / Dart bodies
/// round-trip **verbatim** (IO2). Form fields are introduced by a
/// `<!-- field: name -->` anchor; list items appear as nested `…-N` sections,
/// so list membership is recovered from the paths alone on import.
///
/// Import is a **full overwrite** of the covered scope (IO1): the parsed values
/// replace everything under the imported root(s). There is no conflict
/// resolution in phase 1. Anything that cannot be mapped — an unknown section
/// id, a kind mismatch, an orphaned value block — is collected into the
/// [MarkdownImportResult.rejections] report rather than dropped.
class MarkdownDocument {
  MarkdownDocument(this.controller);

  final SpecDocumentController controller;

  SpecModel get _model => controller.model;

  // The path-segment conventions shared with the controller and the tree.
  static String rootSeg(SpecRoot r) => r.sectionId ?? r.type;
  static String _fieldSeg(SpecField f) => f.sectionId ?? f.name;

  // --- Export -------------------------------------------------------------

  /// Renders the populated subtree of [root] as a schema-conformant markdown
  /// document with a `<!-- docspec: -->` header.
  String exportRoot(SpecRoot root) {
    final b = StringBuffer();
    final seg = rootSeg(root);
    b.writeln('<!-- docspec: ${seg.toLowerCase()}/1 -->');
    b.writeln('# $seg — ${root.title}');
    final cls = _model.classNamed(root.type);
    if (root.description != null && root.description!.trim().isNotEmpty) {
      b.writeln();
      b.writeln(root.description!.trim());
    }
    if (cls != null) {
      _exportClass(b, cls, seg, 2, {root.type});
    }
    return b.toString();
  }

  void _exportClass(
    StringBuffer b,
    SpecClass cls,
    String basePath,
    int depth,
    Set<String> seenTypes,
  ) {
    for (final field in cls.fields) {
      final path = '$basePath/${_fieldSeg(field)}';
      if (!controller.hasValuesUnder(path)) continue;
      switch (field.kind) {
        case SpecFieldKind.content:
        case SpecFieldKind.scalar:
        case SpecFieldKind.enumValue:
          final value = controller.content(path);
          if (value == null) break;
          _heading(b, depth, path, field.name);
          b.writeln(fence(value, info: field.contentType ?? ''));
          b.writeln();
        case SpecFieldKind.form:
          _heading(b, depth, path, field.name);
          for (final ff in field.formFields) {
            final value = controller.formField(path, ff.name);
            if (value == null) continue;
            b.writeln('<!-- field: ${ff.name} -->');
            b.writeln(fence(value));
            b.writeln();
          }
        case SpecFieldKind.list:
          final elem = _model.classNamed(field.elementType);
          final recursive = field.elementType != null &&
              seenTypes.contains(field.elementType);
          _heading(b, depth, path, field.name);
          b.writeln();
          if (elem == null || recursive) break;
          final nextSeen = {...seenTypes, field.elementType!};
          for (final itemPath in controller.listItems(path)) {
            _heading(b, depth + 1, itemPath, field.elementType ?? 'item');
            b.writeln();
            _exportClass(b, elem, itemPath, depth + 2, nextSeen);
          }
        case SpecFieldKind.complex:
        case SpecFieldKind.section:
          final nested = _model.classNamed(field.type);
          final recursive =
              field.type != null && seenTypes.contains(field.type);
          if (nested == null || recursive) break;
          _heading(b, depth, path, field.name);
          b.writeln();
          _exportClass(b, nested, path, depth + 1, {...seenTypes, field.type!});
      }
    }
  }

  /// Writes a `## <path> — <name>` heading at [depth] (capped at the markdown
  /// maximum of 6). The path is the first whitespace-free token so the parser
  /// recovers it exactly.
  static void _heading(StringBuffer b, int depth, String path, String name) {
    final hashes = '#' * (depth > 6 ? 6 : depth);
    b.writeln('$hashes $path — $name');
  }

  /// A fenced code block holding [value] verbatim. The fence is one backtick
  /// longer than the longest backtick run in [value] (min 3), so no value line
  /// can be mistaken for the closing fence — embedded code fences survive.
  static String fence(String value, {String info = ''}) {
    var maxRun = 0;
    var run = 0;
    for (final unit in value.codeUnits) {
      if (unit == 0x60) {
        run++;
        if (run > maxRun) maxRun = run;
      } else {
        run = 0;
      }
    }
    final n = (maxRun + 1) < 3 ? 3 : maxRun + 1;
    final f = '`' * n;
    final sb = StringBuffer()..writeln('$f$info');
    for (final line in value.split('\n')) {
      sb.writeln(line);
    }
    sb.write(f);
    return sb.toString();
  }

  // --- Import -------------------------------------------------------------

  /// Parses [text] into staged values + a rejection report, **without**
  /// mutating the document. The caller applies the result as a full overwrite.
  MarkdownImportResult parse(String text) {
    final lines = text.split('\n');
    final content = <String, String>{};
    final forms = <String, Map<String, String>>{};
    final rejections = <MarkdownRejection>[];
    final rootPrefixes = <String>{};

    // The leaf the next fenced block fills: a (kind, path, [field]) pending
    // target, or null when no value is expected.
    _Pending? pending;

    void flushMissing() {
      if (pending != null && !pending!.filled) {
        rejections.add(MarkdownRejection(
          line: pending!.line,
          reason: MarkdownRejectReason.missingValue,
          anchor: pending!.anchor,
          message: 'no fenced value followed this anchor',
        ));
      }
      pending = null;
    }

    var i = 0;
    SpecFieldKind? currentKind; // kind of the current heading
    String? currentPath;
    while (i < lines.length) {
      final raw = lines[i];
      final lineNo = i + 1;
      final trimmed = raw.trimRight();

      // Heading.
      final heading = _headingPath(trimmed);
      if (heading != null) {
        flushMissing();
        final path = heading;
        final node = controller.resolve(path);
        if (node == null) {
          rejections.add(MarkdownRejection(
            line: lineNo,
            reason: MarkdownRejectReason.unknownSection,
            anchor: path,
            message: 'section path does not resolve against the model',
          ));
          currentKind = null;
          currentPath = null;
          i++;
          continue;
        }
        currentKind = node.kind;
        currentPath = path;
        rootPrefixes.add(path.split('/').first);
        // A content/scalar/enum heading expects a value next.
        if (currentKind == SpecFieldKind.content ||
            currentKind == SpecFieldKind.scalar ||
            currentKind == SpecFieldKind.enumValue) {
          pending = _Pending.content(lineNo, path);
        }
        i++;
        continue;
      }

      // Form-field anchor.
      final field = _fieldAnchor(trimmed);
      if (field != null) {
        flushMissing();
        if (currentPath == null || currentKind != SpecFieldKind.form) {
          rejections.add(MarkdownRejection(
            line: lineNo,
            reason: MarkdownRejectReason.kindMismatch,
            anchor: field,
            message: 'form-field anchor outside a `@Form` section',
          ));
          i++;
          continue;
        }
        pending = _Pending.form(lineNo, currentPath, field);
        i++;
        continue;
      }

      // Fence opener.
      final fenceLen = _fenceOpen(trimmed);
      if (fenceLen != null) {
        final body = <String>[];
        var j = i + 1;
        final closer = '`' * fenceLen;
        while (j < lines.length && lines[j].trimRight() != closer) {
          body.add(lines[j]);
          j++;
        }
        final value = body.join('\n');
        if (pending == null) {
          rejections.add(MarkdownRejection(
            line: lineNo,
            reason: MarkdownRejectReason.orphanBlock,
            message: 'fenced value with no owning section or field',
          ));
        } else if (pending!.field != null) {
          forms.putIfAbsent(pending!.path, () => {})[pending!.field!] = value;
          pending!.filled = true;
        } else {
          content[pending!.path] = value;
          pending!.filled = true;
        }
        pending = null;
        i = (j < lines.length) ? j + 1 : j; // skip past the closing fence
        continue;
      }

      i++;
    }
    flushMissing();

    final lists = _reconstructLists(content.keys, forms.keys);
    return MarkdownImportResult(
      content: content,
      forms: forms,
      lists: lists,
      rejections: rejections,
      rootPrefixes: rootPrefixes,
    );
  }

  /// Recovers list membership from the leaf paths: any `<base>-<n>` segment
  /// whose `<base>` ancestor resolves to a list field denotes item `<n>` of
  /// that list. Items keep their encounter order (which export emits in
  /// document order); `seq` is the largest item number seen.
  Map<String, Map<String, Object?>> _reconstructLists(
    Iterable<String> contentKeys,
    Iterable<String> formKeys,
  ) {
    final items = <String, List<String>>{};
    final seq = <String, int>{};
    void scan(String path) {
      final segs = path.split('/');
      var prefix = segs.first;
      for (var k = 1; k < segs.length; k++) {
        final seg = segs[k];
        final m = RegExp(r'^(.+)-(\d+)$').firstMatch(seg);
        if (m != null) {
          final listPath = '$prefix/${m.group(1)}';
          final itemPath = '$prefix/$seg';
          final node = controller.resolve(listPath);
          if (node?.kind == SpecFieldKind.list) {
            final list = items.putIfAbsent(listPath, () => []);
            if (!list.contains(itemPath)) list.add(itemPath);
            final n = int.parse(m.group(2)!);
            if (n > (seq[listPath] ?? 0)) seq[listPath] = n;
          }
        }
        prefix = '$prefix/$seg';
      }
    }

    for (final p in contentKeys) {
      scan(p);
    }
    for (final p in formKeys) {
      scan(p);
    }
    return {
      for (final e in items.entries)
        e.key: {'seq': seq[e.key] ?? e.value.length, 'items': e.value},
    };
  }

  /// The section path of a heading line (`#{1,6} <path> …`), or null when the
  /// line is not a heading. The path is the first whitespace-free token after
  /// the hashes; an em-dash title may follow.
  static String? _headingPath(String line) {
    final m = RegExp(r'^(#{1,6})\s+(\S+)').firstMatch(line);
    if (m == null) return null;
    return m.group(2);
  }

  /// The field name of a `<!-- field: name -->` anchor line, or null.
  static String? _fieldAnchor(String line) {
    final m = RegExp(r'^<!--\s*field:\s*(\S+)\s*-->$').firstMatch(line.trim());
    return m?.group(1);
  }

  /// The fence length of a fence-opener line (3+ backticks, optional info), or
  /// null when the line does not open a fence.
  static int? _fenceOpen(String line) {
    final m = RegExp(r'^(`{3,})').firstMatch(line);
    if (m == null) return null;
    // A pure-backtick line is a closer, not an opener; openers may carry info.
    return m.group(1)!.length;
  }
}

/// A pending value target between a section/field anchor and its fenced block.
class _Pending {
  _Pending.content(this.line, this.path) : field = null;
  _Pending.form(this.line, this.path, this.field);

  final int line;
  final String path;
  final String? field;
  bool filled = false;

  String get anchor => field != null ? '$path :: $field' : path;
}
