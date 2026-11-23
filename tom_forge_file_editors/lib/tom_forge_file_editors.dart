/// The light file editors of a Forge shell: the plain-text editor, the
/// `.env` editor and the todo-file editor, each editing one file through a
/// `ForgeFileSession` that keeps its bytes and saves it, and the module that
/// opens files in them — and in the file kinds the application registers
/// with it (the Markdown and YAML adapters' `forgeMarkdownFileKind` and
/// `forgeYamlFileKind`, through a `ForgeFileKindRegistry`).
library;

// The session-file binding and frame the editors use: the kit's and
// tom_forge_shared_ui's, re-exported under the names they always had here.
export 'package:tom_forge_kit/tom_forge_kit.dart'
    show
        ForgeFileKindRegistry,
        ForgeFileKindRequest,
        ForgeKitFileKind,
        ForgeSessionFile;
export 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show ForgeSessionFileFrame;

export 'src/env_file_editor.dart';
export 'src/file_editors_module.dart';
export 'src/file_kind.dart';
export 'src/protected_clipboard.dart';
export 'src/todo_file_editor.dart';
