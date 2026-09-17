/// Rendering a `file:` SVG, on the platforms that have files.
///
/// `flutter_svg` picks its own `File` type with
/// `export '_file_io.dart' if (dart.library.js_interop) '_file_none.dart'`, so
/// on the web `SvgPicture.file` takes an abstract `File` that is **not**
/// `dart:io`'s. Our `dart:io` `File` compiles perfectly well for the web — the
/// library is a declared dart2js library (see `tom_dart_editor`'s README) — and
/// that is exactly what makes the clash possible: both types exist, and they
/// are not the same type.
///
/// The `!kIsWeb` guard at the call site does not help, because it is a runtime
/// condition and this is a compile-time type check. A conditional import is the
/// mechanism that operates at the right time.
library;

export 'svg_file_source_io.dart'
    if (dart.library.js_interop) 'svg_file_source_web.dart';
