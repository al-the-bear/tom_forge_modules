import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

import 'forge_office_trail.dart';

/// The LibreOfficeKit editor's host in Forge (`TomOfficeEditorHost`): the
/// file's local path, the binary save rules, the helper launcher the module
/// holds for the current LibreOffice (detected with the path setting
/// `forge.tools.libreoffice.path`, `tom_office_host` from the binaries
/// layer), the kit's notifications for notices, the application's way of
/// opening links outside ([openExternal]) and its file pickers for *Insert
/// image*; history changes go to the editor, which tells the application.
class ForgeOfficeHost implements TomOfficeEditorHost {
  /// A host of the file at [filePath] in the application of [api].
  /// [launcher] answers the module's current launcher each time the editor
  /// (re)starts a helper.
  ForgeOfficeHost({
    required this.filePath,
    required this.api,
    required this.files,
    required TomOfficeHelperLauncher Function() launcher,
    this.openExternal,
    this.filePickers,
    Future<String?> Function()? pickImage,
  }) : _launcher = launcher,
       _pickImage = pickImage;

  @override
  final String filePath;

  /// The application's API (notifications).
  final ForgeKitApi api;

  @override
  final TomBinaryFiles files;

  /// Opens a link outside the application (the panel shell:
  /// `shell.environment.openExternal`); null: links are not opened.
  final Future<void> Function(Uri uri)? openExternal;

  /// The application's file pickers (the panel shell:
  /// `ForgeShellComponents.of(shell).pickers`); null: none.
  final ForgeFilePickers Function()? filePickers;

  final TomOfficeHelperLauncher Function() _launcher;
  final Future<String?> Function()? _pickImage;

  /// Called when the editor's history or dirty state changed.
  VoidCallback? onHistoryChanged;

  @override
  String get name {
    final slash = filePath.lastIndexOf(RegExp(r'[/\\]'));
    return slash < 0 ? filePath : filePath.substring(slash + 1);
  }

  @override
  TomOfficeHelperLauncher get helper => _launcher();

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
    forgeOfficeTrail('open link (${uri.scheme})');
    unawaited(
      open(uri).catchError(
        (Object e, StackTrace s) => forgeOfficeReport(e, s, 'opening a link'),
      ),
    );
  }

  @override
  void historyChanged() => onHistoryChanged?.call();

  /// *Insert image*: the application's file picker (images), or the picker
  /// the module was given.
  @override
  Future<String?> pickImage() async {
    final pick = _pickImage;
    if (pick != null) return pick();
    final pickers = filePickers?.call();
    if (pickers == null || !pickers.available) return null;
    final picked = await pickers.pickFiles(
      title: 'Insert image',
      extensions: const [
        'png',
        'jpg',
        'jpeg',
        'gif',
        'bmp',
        'svg',
        'tif',
        'tiff',
        'webp',
      ],
    );
    return picked.isEmpty ? null : picked.first;
  }
}
