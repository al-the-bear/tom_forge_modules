/// Forge's undo/redo contract ([ForgeUndoManager]) and its default
/// implementation ([DefaultUndoManager], over `tom_undo`'s stack), on their
/// own.
///
/// A **narrow, platform-neutral** entry point beside the default
/// `tom_forge_core.dart` barrel, which reaches `dart:io` through the gitignore
/// walk. dart2js does **not** reject `dart:io`: it compiles against web stubs
/// that throw at *runtime*, so containment at the import boundary is the only
/// thing that catches a browser crash early.
///
/// `tom_webwork_core` takes the contract from here in an entry point that must
/// stay web-linkable (Webwork→Forge is the permitted licence direction), and
/// `tool/package_seams.dart` bans the barrel URI from that entry point by
/// name. Code that wants only the stack takes `package:tom_undo/tom_undo.dart`.
library;

export 'src/defaults/default_undo_manager.dart';
export 'src/services/forge_undo_manager.dart';
export 'src/types/forge_listenable.dart';
