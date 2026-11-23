import 'package:flutter/widgets.dart' show IconData;
import 'package:tom_file_session/tom_file_session.dart' show ForgeFileSession;

import '../components/forge_editor.dart';
import '../kit/forge_kit_api.dart';
import '../module/forge_kit_module.dart';

/// What a file kind gets to make the editor of one file: the file's session,
/// the module the editor belongs to and the API of the application it runs
/// in.
///
/// The session is made by the module that opens the file and loaded once the
/// editor exists; the editor reads and saves the file through it.
class ForgeFileKindRequest {
  const ForgeFileKindRequest({
    required this.session,
    required this.module,
    this.api,
  });

  /// The file, read and saved through it.
  final ForgeFileSession session;

  /// The module the new editor belongs to.
  final ForgeKitModule module;

  /// The API of the application, when there is one; null otherwise (the
  /// editor then reaches it through its module, if at all).
  final ForgeKitApi? api;
}

/// A kind of file a module opens over a [ForgeFileSession], by the file's
/// name: an id, the name and icon **Open With** shows, the file extensions it
/// takes and the factory that makes the editor of one file.
///
/// It names no panel, tab or window. An editor adapter exports its kind
/// (e.g. `forgeMarkdownFileKind`); the application decides which kinds it
/// takes and hands them to the module that opens files
/// ([ForgeFileKindRegistry]).
class ForgeKitFileKind {
  const ForgeKitFileKind({
    required this.id,
    required this.label,
    required this.icon,
    required this.extensions,
    required this.create,
  });

  /// The kind's id: the id of its **Open With** choice (the key a file-type
  /// default names) and the key a host's replacement editor is given under.
  final String id;

  /// The name **Open With** shows.
  final String label;

  /// The icon **Open With** shows.
  final IconData icon;

  /// The file extensions (without the dot, lower case) of this kind.
  final List<String> extensions;

  /// Makes the editor of one file of this kind.
  final ForgeEditor Function(ForgeFileKindRequest request) create;

  /// Whether a file named [name] (its last path segment, any case) is of
  /// this kind: its extension is one of [extensions].
  bool matches(String name) {
    final lower = name.toLowerCase();
    for (final extension in extensions) {
      if (lower.endsWith('.$extension')) return true;
    }
    return false;
  }

  @override
  String toString() => 'ForgeKitFileKind($id)';
}

/// The file kinds a module opens files with, in the order they are asked:
/// the first kind whose [ForgeKitFileKind.matches] answers true takes the
/// file.
///
/// An application fills it with the kinds of the adapters it takes and hands
/// it to its file module, which asks it instead of naming the kinds; nothing
/// registers itself on import.
class ForgeFileKindRegistry {
  /// A registry holding [kinds], in order.
  ForgeFileKindRegistry([Iterable<ForgeKitFileKind> kinds = const []]) {
    kinds.forEach(register);
  }

  final _kinds = <ForgeKitFileKind>[];

  /// The kinds, in the order they are asked.
  List<ForgeKitFileKind> get kinds => List.unmodifiable(_kinds);

  /// Adds [kind] at the end; a kind of the same id is replaced in its place.
  void register(ForgeKitFileKind kind) {
    final index = _kinds.indexWhere((k) => k.id == kind.id);
    if (index < 0) {
      _kinds.add(kind);
    } else {
      _kinds[index] = kind;
    }
  }

  /// The kind of the file named [name], or null when none takes it.
  ForgeKitFileKind? kindOf(String name) {
    for (final kind in _kinds) {
      if (kind.matches(name)) return kind;
    }
    return null;
  }

  /// The kind with [id], or null.
  ForgeKitFileKind? byId(String id) {
    for (final kind in _kinds) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}
