import 'dart:async';

import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../defaults/stub_services.dart';
import '../defaults/default_shell_api.dart';
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

/// What an editor type gets to open one file in the panel shell: the kit's
/// request ([ForgeKitEditorRequest]) with the module that owns the shell's
/// own editors as a [ForgeModule] and the shell's layout controller, which is
/// also the request's `host`.
class ForgeEditorTypeRequest extends ForgeKitEditorRequest {
  const ForgeEditorTypeRequest({
    required super.uri,
    required super.content,
    required ForgeModule super.module,
    required TomFileSystem super.fileSystem,
    required this.layout,
    super.api,
  }) : super(host: layout);

  @override
  ForgeModule get module => super.module as ForgeModule;

  @override
  TomFileSystem get fileSystem => super.fileSystem!;

  final ForgeLayoutController layout;
}

/// One of the editor types the layout controller opens files with by itself
/// (after the modules' editors had their say), as the panel shell declares
/// one: its factory takes the shell's [ForgeEditorTypeRequest]. The shell
/// takes any [ForgeKitEditorType] (the Markdown, Dart and YAML adapters'
/// `forgeMarkdownEditorType`, `forgeDartEditorType`, `forgeYamlEditorType`);
/// its own `'plaintext'` is built in.
class ForgeEditorType extends ForgeKitEditorType {
  ForgeEditorType({
    required super.id,
    required super.label,
    required super.description,
    required ForgeEditor Function(ForgeEditorTypeRequest request) create,
    super.extensions,
    super.contentTypes,
    super.icon,
  }) : super(create: (request) => create(request as ForgeEditorTypeRequest));
}

/// The parts a Forge shell is assembled from that the shell core does not
/// carry itself: the terminal manager (and the view of a terminal), the
/// secret storage, editor types beyond plain text ([ForgeKitEditorType]s),
/// and the host's file pickers and environment.
///
/// The core works without any of them — no terminals
/// ([ForgeNoTerminalManager]), secrets in memory ([DefaultSecretStorage]),
/// files opened as plain text, no file pickers ([ForgeNoFilePickers]) and no
/// host environment ([ForgeNoHostEnvironment]) — so it builds where the
/// terminal, the editors or `dart:io` do not, the web included.
/// `tom_forge_terminal`, the editor adapters (`tom_forge_md_editor`,
/// `tom_forge_dart_editor`, `tom_forge_yaml_editor`),
/// `tom_forge_platform_secrets` and `tom_forge_desktop_host` provide them;
/// `package:tom_forge_ui`'s `useForgeDesktopComponents()` registers all
/// four as [registered], which
/// every shell made afterwards takes unless it is given its own.
class ForgeShellComponents {
  const ForgeShellComponents({
    this.terminalManager,
    this.secretStorage,
    this.terminalView,
    this.editorTypes = const [],
    this.filePickers,
    this.hostEnvironment,
  });

  /// Makes the terminal manager; null: no terminals.
  final ForgeTerminalManagerFactory? terminalManager;

  /// Makes the secret storage; null: secrets kept in memory.
  final ForgeSecretStorageFactory? secretStorage;

  /// Makes the view of a terminal; null: a terminal shows as its name.
  final ForgeTerminalViewBuilder? terminalView;

  /// The editor types beyond plain text, in the order they are offered.
  final List<ForgeKitEditorType> editorTypes;

  /// The host's file pickers; null: none ([ForgeNoFilePickers]).
  final ForgeFilePickers? filePickers;

  /// The host environment; null: none ([ForgeNoHostEnvironment]).
  final ForgeHostEnvironment? hostEnvironment;

  /// The file pickers to use: [filePickers], or none.
  ForgeFilePickers get pickers => filePickers ?? const ForgeNoFilePickers();

  /// The host environment to use: [hostEnvironment], or none.
  ForgeHostEnvironment get host =>
      hostEnvironment ?? const ForgeNoHostEnvironment();

  /// The components of [shell] (a [DefaultShellApi]), else [registered].
  static ForgeShellComponents of(Object? shell) =>
      shell is DefaultShellApi ? shell.components : registered;

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
      filePickers: other.filePickers ?? filePickers,
      hostEnvironment: other.hostEnvironment ?? hostEnvironment,
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
