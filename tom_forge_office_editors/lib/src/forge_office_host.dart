import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

import 'forge_office_trail.dart';

/// The office editors' host in Forge (`TomOfficeEditorHost`, for the
/// LibreOfficeKit editor and ZetaOffice alike): the file's local path, the
/// binary save rules, the helper launcher the module holds for the current
/// LibreOffice (detected with the path setting `forge.tools.libreoffice.path`,
/// `tom_office_host` from the binaries layer), the shell's notifications and
/// external links, the shell's file picker for *Insert image*; history
/// changes go to the editor, which tells the shell.
class ForgeOfficeHost implements TomOfficeEditorHost {
  /// A host of the file at [filePath]. [launcher] answers the module's
  /// current launcher each time the editor (re)starts a helper.
  ForgeOfficeHost({
    required this.filePath,
    required this.shell,
    required this.files,
    required TomOfficeHelperLauncher Function() launcher,
    Future<String?> Function()? pickImage,
  }) : _launcher = launcher,
       _pickImage = pickImage;

  @override
  final String filePath;

  /// The shell.
  final ForgeShellApi shell;

  @override
  final TomBinaryFiles files;

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
    forgeOfficeTrail('open link (${uri.scheme})');
    unawaited(shell.environment.openExternal(uri));
  }

  @override
  void historyChanged() => onHistoryChanged?.call();

  /// *Insert image*: the shell's file picker (images), or the picker the
  /// module was given.
  @override
  Future<String?> pickImage() async {
    final pick = _pickImage;
    if (pick != null) return pick();
    final pickers = ForgeShellComponents.registered.pickers;
    if (!pickers.available) return null;
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
