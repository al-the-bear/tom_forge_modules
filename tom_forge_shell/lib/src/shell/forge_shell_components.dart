import 'dart:async';

import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_editor.dart';
import '../components/forge_view.dart';
import '../defaults/stub_services.dart';
import '../module/forge_module.dart';
import 'forge_layout_controller.dart';

/// Makes the terminal manager of a shell over [fileSystem].
typedef ForgeTerminalManagerFactory =
    ForgeTerminalManager Function(TomFileSystem fileSystem);

/// Makes the secret storage of a shell over [fileSystem].
typedef ForgeSecretStorageFactory =
    ForgeSecretStorage Function(TomFileSystem fileSystem);

/// Makes the view that shows [terminal] as a section of the bottom panel's
/// Terminal tab.
typedef ForgeTerminalViewBuilder = ForgeView Function(ForgeTerminal terminal);

/// What an editor type gets to open one file: the file, its content, the
/// module that owns the shell's own editors, the shell's file system and
/// layout controller.
class ForgeEditorTypeRequest {
  const ForgeEditorTypeRequest({
    required this.uri,
    required this.content,
    required this.module,
    required this.fileSystem,
    required this.layout,
  });

  final Uri uri;
  final String content;
  final ForgeModule module;
  final TomFileSystem fileSystem;
  final ForgeLayoutController layout;
}

/// One of the editor types the layout controller opens files with by itself
/// (after the modules' editors had their say): `'md'`, `'dart'`, `'yaml'`
/// from `tom_forge_code_editors`, and the shell's own `'plaintext'`.
class ForgeEditorType {
  const ForgeEditorType({
    required this.id,
    required this.label,
    required this.description,
    required this.create,
    this.extensions = const [],
  });

  /// The id an editor of this type answers as
  /// [ForgeEditorOfType.editorTypeId],
  /// and the file-type defaults name.
  final String id;

  /// The name **Open With** shows.
  final String label;

  /// What **Open With** says it is for.
  final String description;

  /// The file extensions (without the dot, lower case) this type opens by
  /// default.
  final List<String> extensions;

  /// Makes an editor of this type for one file.
  final ForgeEditor Function(ForgeEditorTypeRequest request) create;
}

/// The parts a Forge shell is assembled from that the shell core does not
/// carry itself: the terminal manager (and the view of a terminal), the
/// secret storage, and editor types beyond plain text.
///
/// The core works without any of them — no terminals
/// ([ForgeNoTerminalManager]), secrets in memory ([DefaultSecretStorage]),
/// files opened as plain text — so it builds where the terminal or the
/// editors do not. `tom_forge_terminal`, `tom_forge_code_editors` and
/// `tom_forge_platform_secrets` provide them; `package:tom_forge_ui`'s
/// `useForgeDesktopComponents()` registers all three as [registered], which
/// every shell made afterwards takes unless it is given its own.
class ForgeShellComponents {
  const ForgeShellComponents({
    this.terminalManager,
    this.secretStorage,
    this.terminalView,
    this.editorTypes = const [],
  });

  /// Makes the terminal manager; null: no terminals.
  final ForgeTerminalManagerFactory? terminalManager;

  /// Makes the secret storage; null: secrets kept in memory.
  final ForgeSecretStorageFactory? secretStorage;

  /// Makes the view of a terminal; null: a terminal shows as its name.
  final ForgeTerminalViewBuilder? terminalView;

  /// The editor types beyond plain text, in the order they are offered.
  final List<ForgeEditorType> editorTypes;

  /// The components every shell takes unless it is given its own; none
  /// until an application registers them (see [register]).
  static ForgeShellComponents registered = const ForgeShellComponents();

  /// Adds [components] to [registered]: a factory or builder it names
  /// replaces the registered one, and its editor types replace registered
  /// types of the same id.
  static void register(ForgeShellComponents components) {
    registered = registered.mergedWith(components);
  }

  /// These components with [other]'s on top.
  ForgeShellComponents mergedWith(ForgeShellComponents other) {
    final types = {for (final t in editorTypes) t.id: t};
    for (final t in other.editorTypes) {
      types[t.id] = t;
    }
    return ForgeShellComponents(
      terminalManager: other.terminalManager ?? terminalManager,
      secretStorage: other.secretStorage ?? secretStorage,
      terminalView: other.terminalView ?? terminalView,
      editorTypes: types.values.toList(growable: false),
    );
  }

  /// The terminal manager of a shell over [fileSystem].
  ForgeTerminalManager terminalManagerFor(TomFileSystem fileSystem) =>
      terminalManager?.call(fileSystem) ?? ForgeNoTerminalManager();

  /// The secret storage of a shell over [fileSystem].
  ForgeSecretStorage secretStorageFor(TomFileSystem fileSystem) =>
      secretStorage?.call(fileSystem) ?? DefaultSecretStorage();
}

/// A terminal manager without terminals, for a shell built without
/// `tom_forge_terminal`: it holds none, and [create] refuses.
class ForgeNoTerminalManager implements ForgeTerminalManager {
  final _opened = StreamController<ForgeTerminal>.broadcast();
  final _closed = StreamController<ForgeTerminal>.broadcast();
  final _active = StreamController<ForgeTerminal?>.broadcast();

  @override
  ForgeTerminal create({
    String? name,
    String? shellPath,
    String? cwd,
    ForgeOutputChannel? outputChannel,
  }) => throw UnsupportedError(
    'This shell has no terminals: register a terminal manager '
    '(tom_forge_terminal) with ForgeShellComponents.',
  );

  @override
  List<ForgeTerminal> get terminals => const [];

  @override
  ForgeTerminal? get activeTerminal => null;

  @override
  void setActive(ForgeTerminal terminal) {}

  @override
  void detach(ForgeTerminal terminal) {}

  @override
  Stream<ForgeTerminal> get onDidOpen => _opened.stream;

  @override
  Stream<ForgeTerminal> get onDidClose => _closed.stream;

  @override
  Stream<ForgeTerminal?> get onDidChangeActive => _active.stream;
}
