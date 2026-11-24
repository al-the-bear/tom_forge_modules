import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

import 'forge_zetaoffice_trail.dart';

/// The ZetaOffice editor's host in Forge (`TomOfficeEditorHost`, the office
/// editor's host interface the ZetaOffice route runs on): the file's local
/// path, the binary save rules, the kit's notifications for notices, the
/// application's way of opening links outside ([openExternal]); history
/// changes go to the editor, which tells the application. ZetaOffice starts
/// no LibreOffice helper and inserts no image through the host: [helper]
/// refuses to start one, [pickImage] answers null.
class ForgeZetaOfficeHost implements TomOfficeEditorHost {
  /// A host of the file at [filePath] in the application of [api].
  ForgeZetaOfficeHost({
    required this.filePath,
    required this.api,
    required this.files,
    this.openExternal,
  });

  @override
  final String filePath;

  /// The application's API (notifications).
  final ForgeKitApi api;

  @override
  final TomBinaryFiles files;

  /// Opens a link outside the application (the panel shell:
  /// `shell.environment.openExternal`); null: links are not opened.
  final Future<void> Function(Uri uri)? openExternal;

  /// Called when the editor's history or dirty state changed.
  VoidCallback? onHistoryChanged;

  @override
  String get name {
    final slash = filePath.lastIndexOf(RegExp(r'[/\\]'));
    return slash < 0 ? filePath : filePath.substring(slash + 1);
  }

  @override
  TomOfficeHelperLauncher get helper => const _NoHelper();

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
    final open = openExternal;
    if (uri == null || open == null) return;
    forgeZetaOfficeTrail('open link (${uri.scheme})');
    unawaited(
      open(uri).catchError(
        (Object e, StackTrace s) =>
            forgeZetaOfficeReport(e, s, 'opening a link'),
      ),
    );
  }

  @override
  void historyChanged() => onHistoryChanged?.call();

  /// ZetaOffice inserts images in its own interface.
  @override
  Future<String?> pickImage() async => null;
}

/// ZetaOffice runs in the webview: no LibreOffice helper is ever started.
class _NoHelper implements TomOfficeHelperLauncher {
  const _NoHelper();

  @override
  LibreOfficeInstallation get installation =>
      const LibreOfficeInstallation(state: LibreOfficeState.missing);

  @override
  Future<TomOfficeHelperChannel> start({required String documentPath}) =>
      Future.error(StateError('ZetaOffice starts no LibreOffice helper'));
}
