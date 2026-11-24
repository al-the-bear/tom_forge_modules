import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';
import 'package:tom_pdf_pdfium/tom_pdf_pdfium.dart';

import 'forge_pdf_trail.dart';

/// The PDFium editor's host in Forge (`TomPdfEditorHost`): the file's path in
/// the application's file system, the binary save rules, PDFium from the
/// binaries layer as the engine status, the kit's notifications, external
/// links through the application's [openExternal]; history changes go to the
/// editor, which tells the application.
class ForgePdfHost implements TomPdfEditorHost {
  ForgePdfHost({
    required this.filePath,
    required this.api,
    required this.files,
    required TomPdfiumLibrary Function() locatePdfium,
    required Future<TomPdfEngine> Function(TomPdfiumLibrary library)
    startEngine,
    this.openExternal,
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

  /// The API of the application the editor runs in.
  final ForgeKitApi api;

  @override
  final TomBinaryFiles files;

  @override
  final String authorName;

  /// Opens a link outside the application (the panel shell's
  /// `environment.openExternal`); null: links are not opened.
  final Future<void> Function(Uri uri)? openExternal;

  final TomPdfiumLibrary Function() _locate;
  final Future<TomPdfEngine> Function(TomPdfiumLibrary library) _start;

  /// Called when the editor's history or dirty state changed.
  VoidCallback? onHistoryChanged;

  @override
  String get name => filePath.split(Platform.pathSeparator).last;

  /// Where PDFium is, or why it cannot be used.
  @override
  TomPdfiumLibrary get engineStatus => _locate();

  @override
  Future<TomPdfEngine> startEngine(TomPdfiumLibrary status) => _start(status);

  @override
  void notice(BuildContext context, String message, {required String kind}) {
    final notifications = api.notifications;
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
    final open = openExternal;
    if (open == null) {
      forgePdfiumTrail('open link (${uri.scheme}): no openExternal, ignored');
      return;
    }
    forgePdfiumTrail('open link (${uri.scheme})');
    unawaited(open(uri));
  }

  @override
  void historyChanged() => onHistoryChanged?.call();
}
