/// The local file system: [ForgeLocalFileSystem], with the platform parts it
/// stands on — one watch per directory where the platform has no recursive
/// watch, the freedesktop.org home trash, and the Windows Recycle Bin.
///
/// Uses `dart:io` and `dart:ffi`; a browser build takes `files.dart` alone.
library;

export 'files.dart';
export 'src/files/io/directory_watches.dart';
export 'src/files/io/local_file_system.dart';
export 'src/files/io/xdg_trash.dart';
export 'src/files/io/windows_recycle_bin.dart';
