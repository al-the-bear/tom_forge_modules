import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;

import '../kit/forge_kit_api.dart';
import '../module/forge_kit_module.dart';
import 'forge_editor.dart';

/// What an editor type gets to open one file: the file and its content, the
/// module the editor belongs to, the API of the application it runs in, its
/// file system, and an opaque [host] value.
///
/// No panel, tab or window: where the editor appears is the application's
/// decision ([ForgeKitApi.editorHost]). An application may narrow the request
/// to a type of its own (the panel shell's request adds its layout
/// controller).
class ForgeKitEditorRequest {
  const ForgeKitEditorRequest({
    required this.uri,
    required this.content,
    required this.module,
    this.api,
    this.fileSystem,
    this.host,
  });

  /// The file to open.
  final Uri uri;

  /// The file's content, read as text.
  final String content;

  /// The module the new editor belongs to.
  final ForgeKitModule module;

  /// The API of the application, when the module is activated; null
  /// otherwise (the editor then works on its own, without the application's
  /// actions, settings and diagnostics).
  final ForgeKitApi? api;

  /// The application's file system, when it has one.
  final TomFileSystem? fileSystem;

  /// An opaque value the application hands its editor types, unread by the
  /// kit (the panel shell: its layout controller). An editor type keys
  /// per-application settings by it.
  final Object? host;
}

/// One kind of editor an application opens files with by itself, by file
/// extension: an id, a name, the extensions it opens by default and the
/// factory that makes an editor for one file.
///
/// It names no panel, tab or window. An editor package exports its type
/// (e.g. `forgeYamlEditorType`); the application decides which types it
/// takes and in which order **Open With** offers them (the panel shell takes
/// them through its components).
class ForgeKitEditorType {
  const ForgeKitEditorType({
    required this.id,
    required this.label,
    required this.create,
    this.description = '',
    this.extensions = const [],
  });

  /// The id an editor of this type answers as
  /// [ForgeEditorOfType.editorTypeId], and the file-type defaults name.
  final String id;

  /// The name **Open With** shows.
  final String label;

  /// What **Open With** says it is for.
  final String description;

  /// The file extensions (without the dot, lower case) this type opens by
  /// default.
  final List<String> extensions;

  /// Makes an editor of this type for one file.
  final ForgeEditor Function(ForgeKitEditorRequest request) create;

  /// Whether this type opens [uri] by default (its extension is one of
  /// [extensions], any case).
  bool opensByDefault(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return extensions.contains(name.substring(dot + 1).toLowerCase());
  }

  @override
  String toString() => 'ForgeKitEditorType($id)';
}

/// A module that knows the API it was activated with: an editor created for
/// it reaches the application through [activeKitApi].
abstract interface class ForgeKitApiProvider {
  /// The API the module was activated with; null before activation and
  /// after deactivation.
  ForgeKitApi? get activeKitApi;
}

/// The API [module] was activated with, when it tells
/// ([ForgeKitApiProvider]); else null.
ForgeKitApi? forgeKitApiOf(ForgeKitModule module) =>
    module is ForgeKitApiProvider
    ? (module as ForgeKitApiProvider).activeKitApi
    : null;
