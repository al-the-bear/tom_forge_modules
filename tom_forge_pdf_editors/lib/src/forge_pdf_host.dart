import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

import 'forge_pdf_trail.dart';

/// The PDF editors' host in Forge (`TomPdfEditorHost`, and so the pdf.js
/// view's `TomPdfViewHost`): the file's path in the shell's file system, the
/// binary save rules, PDFium from the binaries layer, the shell's
/// notifications and external links; history changes go to the editor,
/// which tells the shell.
class ForgePdfHost implements TomPdfEditorHost {
  ForgePdfHost({
    required this.filePath,
    required this.shell,
    required this.files,
    required TomPdfiumLibrary Function() locatePdfium,
    required Future<TomPdfEngine> Function(TomPdfiumLibrary library)
    startEngine,
    String? authorName,
  }) : _locate = locatePdfium,
       _start = startEngine,
       authorName =
           authorName ??
           Platform.environment['USER'] ??
           Platform.environment['USERNAME'] ??
           'Forge';

  @override
  final String filePath;

  /// The shell.
  final ForgeShellApi shell;

  @override
  final TomBinaryFiles files;

  @override
  final String authorName;

  final TomPdfiumLibrary Function() _locate;
  final Future<TomPdfEngine> Function(TomPdfiumLibrary library) _start;

  /// Called when the editor's history or dirty state changed.
  VoidCallback? onHistoryChanged;

  @override
  String get name => filePath.split(Platform.pathSeparator).last;

  @override
  TomPdfiumLibrary get pdfium => _locate();

  @override
  Future<TomPdfEngine> startEngine(TomPdfiumLibrary library) => _start(library);

  @override
  void notice(BuildContext context, String message, {required String kind}) {
    final notifications = shell.notifications;
    unawaited(switch (kind) {
      'error' => notifications.showError(message),
      'warning' => notifications.showWarning(message),
      _ => notifications.showInformation(message),
    });
  }

  @override
  void openLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    forgePdfTrail('open link (${uri.scheme})');
    unawaited(shell.environment.openExternal(uri));
  }

  @override
  void historyChanged() => onHistoryChanged?.call();
}
