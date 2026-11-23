/// An editor that keeps its own history over a file it reads and saves
/// through a [ForgeFileSession]: [ForgeSessionFile] binds the editor's
/// controller to the session (`tom_forge_shared_ui`'s
/// `ForgeSessionFileFrame` shows the file's state above the editor).
///
/// The editor's controller owns the document's one history; the session
/// carries the bytes: it reads the file in its encoding, and a save writes the
/// controller's text back as splices — encoding, byte-order mark and every
/// untouched byte kept — after checking that the file on disk is still the
/// one read. The controllers see `\n` line endings; a CRLF file is written
/// back with CRLF.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_file_session/tom_file_session.dart';

/// The binding of one controller to one session.
class ForgeSessionFile {
  ForgeSessionFile({
    required this.session,
    required this.textOf,
    required this.adopt,
    required this.markSaved,
  }) {
    session.addListener(_onSession);
    _onSession();
  }

  /// The file.
  final ForgeFileSession session;

  /// The controller's text now (`\n` line endings).
  final String Function() textOf;

  /// Shows [text] (`\n` line endings) as content from outside: saved, the
  /// history cleared.
  final void Function(String text) adopt;

  /// The controller's text is the saved text.
  final void Function() markSaved;

  /// Changes of what the banner shows (a conflict, a refusal).
  final ValueNotifier<int> changed = ValueNotifier(0);

  var _loaded = false;
  var _crlf = false;

  /// The file as read; the editor shows nothing else until then.
  bool get loaded => _loaded;

  void _onSession() {
    if (!_loaded && session.state == ForgeFileSessionState.ready) {
      _loaded = true;
      _crlf = session.text.contains('\r\n');
      adopt(_toEditor(session.text));
    }
    changed.value++;
  }

  String _toEditor(String text) => text.replaceAll('\r\n', '\n');
  String _toFile(String text) => _crlf ? text.replaceAll('\n', '\r\n') : text;

  /// Whether a save can run now.
  bool get canSave =>
      _loaded &&
      session.state == ForgeFileSessionState.ready &&
      session.readOnlyReason == null;

  /// Writes the controller's text; a file changed on disk is not written over
  /// (the banner then offers Keep mine / Take theirs).
  Future<ForgeFileSaveOutcome> save() async {
    final text = _toFile(textOf());
    if (text != session.text) session.edit(text, 'Save');
    final outcome = await session.save();
    if (outcome == ForgeFileSaveOutcome.saved ||
        outcome == ForgeFileSaveOutcome.clean) {
      markSaved();
    }
    changed.value++;
    return outcome;
  }

  /// Keeps the editor's text over the disk's; the next save writes it.
  void keepMine() => session.keepMine();

  /// Takes the disk's text, as content from outside.
  void takeTheirs() {
    session.takeTheirs();
    adopt(_toEditor(session.text));
  }

  /// Content from outside the history (a revision restore): saved and shown.
  void replaceWith(String content) {
    session.adoptText(content);
    adopt(_toEditor(content));
  }

  void dispose() {
    session.removeListener(_onSession);
    changed.dispose();
  }
}
