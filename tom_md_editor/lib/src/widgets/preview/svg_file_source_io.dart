import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The SVG at a `file:` [uri], loaded through `flutter_svg`'s own file loader.
Widget svgFromFileUri(Uri uri) => SvgPicture.file(File.fromUri(uri));
