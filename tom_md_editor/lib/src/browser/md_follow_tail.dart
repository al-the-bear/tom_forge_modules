/// Following the end of a growing document — a live trail, a log: while the
/// reader is at the end, new content scrolls into view; once they scroll
/// up, it stops, and [MdFollowTail.resume] starts it again. The VS Code
/// extension's live mode.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_file_system/tom_file_system.dart';

import '../controller/md_editor_controller.dart';

/// Whether the view follows the end.
class MdFollowTail extends ChangeNotifier {
  MdFollowTail({this.threshold = 48});

  /// How close to the end (logical pixels) still counts as at the end.
  final double threshold;

  var _following = true;

  /// Whether new content is to scroll into view.
  bool get following => _following;

  /// The reader stopped scrolling at [pixels] of [maxExtent].
  void scrolled({required double pixels, required double maxExtent}) {
    final at = maxExtent - pixels <= threshold;
    if (at == _following) return;
    _following = at;
    notifyListeners();
  }

  /// Follows the end again.
  void resume() {
    if (_following) return;
    _following = true;
    notifyListeners();
  }
}

/// Keeps a controller showing a file that grows: the file is read through
/// [fileSystem] whenever its size or modification time changes (polled,
/// which also works where a native watch does not — a file behind a
/// symlink), and shown as content from outside. A file that goes away leaves
/// the last content shown.
class MdFileFollower {
  MdFileFollower({
    required this.controller,
    required this.fileSystem,
    required this.uri,
    this.interval = const Duration(seconds: 1),
  });

  final MdEditorController controller;

  /// The file system [uri] is read through.
  final TomFileSystem fileSystem;

  /// The file followed.
  final Uri uri;
  final Duration interval;

  Timer? _timer;
  int? _length;
  DateTime? _modified;

  bool get isRunning => _timer != null;

  /// Reads the file now and then whenever it changes.
  Future<void> start() async {
    await check();
    _timer ??= Timer.periodic(interval, (_) => unawaited(check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reads the file if it changed since the last read.
  Future<void> check() async {
    final TomFileEntry? entry;
    try {
      entry = await fileSystem.stat(uri);
    } on Exception {
      return;
    }
    if (entry == null) return;
    if (entry.size == _length && entry.modified == _modified) return;
    _length = entry.size;
    _modified = entry.modified;
    final String text;
    try {
      text = await fileSystem.readText(uri);
    } on Exception {
      return;
    }
    if (text != controller.markdown) controller.replaceContent(text);
  }
}
