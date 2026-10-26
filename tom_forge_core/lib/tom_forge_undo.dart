/// The undo/redo contract, its default implementation and the stack every
/// undo history in the workspace runs on ([ForgeUndoStack], with
/// [forgeApplyAll] for composite steps), on their own.
///
/// This is a **narrow, platform-neutral** entry point beside the default
/// `tom_forge_core.dart` barrel, and it exists because the barrel exports
/// three file-system libraries that import `dart:io`
/// (`forge_file_system`, `memory_file_system`, `gitignore_loader`) while the
/// undo machinery needs none of them — it is plain Dart over
/// `ForgeValueListenable`.
///
/// The distinction matters more than it looks. dart2js does **not** reject
/// `dart:io`: it compiles against web stubs that throw at *runtime*. So a
/// `dart:io` library that reaches a web build produces a browser crash rather
/// than a build failure, and containment at the import boundary is the only
/// thing that catches it early.
///
/// `tom_webwork_core` reuses this from a default entry point that must stay
/// web-linkable (D2 §7 mandates the reuse; Webwork→Forge is the permitted
/// licence direction, D12 §8), and `tool/package_seams.dart` bans the barrel
/// URI from that entry point by name.
///
/// Consumers that already take the whole shell keep using
/// `package:tom_forge_core/tom_forge_core.dart`, which exports all of this too.
library;

export 'src/defaults/default_undo_manager.dart';
export 'src/defaults/undo_stack.dart';
export 'src/services/forge_undo_manager.dart';
export 'src/types/forge_listenable.dart';
