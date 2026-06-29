import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart';

import 'spec_document_controller.dart';

/// The scope of a markdown import/export (§15.2): one root projection, a subset
/// of roots, or the Solution Blueprint master.
enum MarkdownScope { single, multiple, global }

/// Why an imported markdown block was rejected (§15.2 parse-rejection protocol).
///
/// The codec now lives in the generic runtime; this is the editor's alias for
/// its [SpecMarkdownRejectReason] so existing call sites keep their names.
typedef MarkdownRejectReason = SpecMarkdownRejectReason;

/// One rejected block in a markdown import (§15.2). Alias of the runtime's
/// [SpecMarkdownRejection].
typedef MarkdownRejection = SpecMarkdownRejection;

/// The outcome of parsing a markdown document (§15.2). Alias of the runtime's
/// [SpecMarkdownResult]; values are keyed exactly like [SpecDocument.toJson] so
/// the controller can merge them as a full overwrite of the covered scope.
typedef MarkdownImportResult = SpecMarkdownResult;

/// Controller-facing adapter for the markdown import/export format (§15.2).
///
/// The format and all parse/render logic live in the generic
/// [SpecDocumentMarkdown] codec; this thin wrapper binds it to the editor's
/// [SpecDocumentController] (its model + live document), so the controller and
/// dialogs keep their existing API. Import is a **full overwrite** of the
/// covered scope (IO1): [parse] stages values + a rejection report without
/// mutating the document, and the controller applies them.
class MarkdownDocument {
  MarkdownDocument(this.controller);

  final SpecDocumentController controller;

  SpecDocumentMarkdown get _codec =>
      SpecDocumentMarkdown(controller.model, controller.document);

  /// The path-segment a root contributes to a path (`@SectionId` ?? type).
  static String rootSeg(SpecRoot r) => r.sectionId ?? r.type;

  /// Renders the populated subtree of [root] as a schema-conformant markdown
  /// document with a `<!-- docspec: -->` header.
  String exportRoot(SpecRoot root) => _codec.exportRoot(root);

  /// Parses [text] into staged values + a rejection report, **without**
  /// mutating the document. The caller applies the result as a full overwrite.
  MarkdownImportResult parse(String text) => _codec.parse(text);
}
