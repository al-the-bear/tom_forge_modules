/// Rendering a `file:` image (raster or SVG) referenced from a document, on
/// the platforms that have files: Flutter's own file image providers read
/// the local file, so this is the one place the preview reaches `dart:io` —
/// a platform service, behind a conditional import
/// (`tom_forge/_agent_guidelines/platform_architecture.md` §2.6).
///
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

export 'local_file_image_io.dart'
    if (dart.library.js_interop) 'local_file_image_web.dart';
