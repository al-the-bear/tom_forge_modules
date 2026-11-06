import 'package:flutter/material.dart';
import 'package:tom_file_system/tom_file_system.dart';

import '../structure/review_store.dart';
import '../structure/spec_model.dart';
import 'spec_document_controller.dart';
import 'spec_document_editor.dart';

/// Whether [uri] names a TomSpecs document in YAML: a `*.docspecs.yaml` or a
/// `*.tomspecs.yaml` file.
bool isTomSpecsFile(Uri uri) {
  final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final lower = name.toLowerCase();
  return lower.endsWith('.docspecs.yaml') || lower.endsWith('.tomspecs.yaml');
}

/// The TomSpecs document editor over one spec file of a shell's file system —
/// how a Forge app other than the TomSpecs editor (Webforge) offers it for a
/// `*.docspecs.yaml` or `*.tomspecs.yaml` beside the YAML editor.
///
/// The file is read through [fileSystem] and loaded with its review pass
/// (`tom_specs_editor_specification.md` §15.1): the review entries are the
/// document's own ([ReviewStore.inDocument]), saved with it. The shell saves
/// the editor: [getContent] is the document as `*.docspecs.yaml` text, and
/// [markClean] makes it the save point. Edits, undo and redo are the
/// document controller's, as in the TomSpecs editor.
class SpecFileEditor extends SpecDocumentEditor {
  SpecFileEditor({
    required Uri uri,
    required TomFileSystem fileSystem,
    required Future<SpecModel> model,
  }) : this._(
         uri,
         fileSystem,
         SpecDocumentController(
           modelFuture: model,
           review: ReviewStore.inDocument(),
         ),
       );

  SpecFileEditor._(Uri uri, TomFileSystem fileSystem, SpecDocumentController c)
    : super(
        controller: c,
        uri: uri,
        title: uri.pathSegments.isEmpty ? 'Spec' : uri.pathSegments.last,
      ) {
    loaded = () async {
      await controller.loadDocSpecsText(await fileSystem.readText(uri));
      _isLoaded = true;
    }();
    // A file that is no spec document is reported by the editor itself
    // ([buildMain]); its failure is not an unhandled error.
    loaded.ignore();
  }

  /// Completes when the file is read and loaded; fails with what kept it.
  late final Future<void> loaded;

  bool _isLoaded = false;

  @override
  IconData get icon => Icons.article_outlined;

  /// The document as `*.docspecs.yaml` text, for the shell to write — none
  /// before the file is loaded.
  @override
  String? getContent() => _isLoaded ? controller.encodeDocSpecs() : null;

  /// Content from outside the history (a reload, an external change taken, a
  /// revision restore): the document becomes it in place, saved and with
  /// nothing to undo. Text that is not a spec document is not taken: the
  /// shell then closes the editor and opens the file again, which reports
  /// what is wrong with it.
  @override
  bool replaceContent(String content) {
    if (!_isLoaded) return false;
    try {
      controller.replaceDocSpecsText(content);
    } on Exception {
      return false;
    }
    return true;
  }

  @override
  Widget buildMain(BuildContext context) => FutureBuilder<void>(
    future: loaded,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${uri.pathSegments.last} could not be opened as a TomSpecs '
              'document: ${snapshot.error}',
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return super.buildMain(context);
    },
  );
}
