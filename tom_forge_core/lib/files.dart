/// The file-system contract and everything that works without a disk: the
/// contract and its values, the shared base, the in-memory file system, the
/// text test, and the change notifier an editing session reports through.
/// The editing session, the tree filter and the `.env` codec built on it are
/// `tom_forge_files`.
///
/// Reaches no `dart:io` and no Flutter, so a browser build links it. The
/// local file system is [`io.dart`](io.dart).
library;

export 'src/files/file_system.dart';
export 'src/files/file_system_base.dart';
export 'src/files/memory_file_system.dart';
export 'src/files/text_detection.dart';
export 'src/types/forge_listenable.dart' show ForgeChangeNotifier;
