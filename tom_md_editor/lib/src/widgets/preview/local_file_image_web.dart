import 'package:flutter/widgets.dart';

/// The web has no `file:` URIs to render, and the call site guards on `kIsWeb`
/// before asking — so this exists to keep `dart:io`'s `File` out of the web
/// compile, not to be called. It throws rather than returning a placeholder:
/// a silent empty box would turn a caller's broken guard into a rendering bug
/// nobody traces back here.
Widget svgFromFileUri(Uri uri) => throw UnsupportedError(
      'file: URIs cannot be read in a browser; the caller must check kIsWeb '
      'before asking for $uri',
    );

/// See [svgFromFileUri]: not called on the web.
Widget imageFromFileUri(Uri uri, {ImageErrorWidgetBuilder? errorBuilder}) =>
    throw UnsupportedError(
      'file: URIs cannot be read in a browser; the caller must check kIsWeb '
      'before asking for $uri',
    );
