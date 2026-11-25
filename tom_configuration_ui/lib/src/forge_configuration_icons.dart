import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeIconRef;

/// Makes the [IconData] of a section's [ForgeIconRef], or null when it has
/// none to offer.
///
/// Icons are drawn from constant [IconData]s only: a Flutter build shrinks
/// its icon fonts to the glyphs of the constant icons it finds and refuses an
/// `IconData` made at run time (`flutter build` stops unless
/// `--no-tree-shake-icons`). A description is pure Dart and names its icon by
/// code point, so a resolver maps the code point to a constant icon; an
/// application with icons of its own gives the tiles its own resolver
/// (`ForgeConfigurationScope.iconResolver`).
typedef ForgeConfigurationIconResolver = IconData? Function(ForgeIconRef icon);

/// The Material icons a configuration section commonly names, as constants.
const List<IconData> _materialIcons = [
  Icons.settings,
  Icons.tune,
  Icons.terminal,
  Icons.code,
  Icons.data_object,
  Icons.description,
  Icons.article,
  Icons.keyboard,
  Icons.keyboard_command_key,
  Icons.insert_drive_file,
  Icons.folder,
  Icons.folder_open,
  Icons.build,
  Icons.handyman,
  Icons.extension,
  Icons.palette,
  Icons.color_lens,
  Icons.language,
  Icons.web,
  Icons.public,
  Icons.text_fields,
  Icons.format_size,
  Icons.text_snippet,
  Icons.edit,
  Icons.edit_note,
  Icons.visibility,
  Icons.view_quilt,
  Icons.dashboard,
  Icons.schema,
  Icons.account_tree,
  Icons.functions,
  Icons.picture_as_pdf,
  Icons.table_chart,
  Icons.search,
  Icons.history,
  Icons.security,
  Icons.lock,
  Icons.cloud,
  Icons.storage,
  Icons.smart_toy,
  Icons.notifications,
  Icons.info_outline,
];

final Map<int, IconData> _materialByCodePoint = {
  for (final icon in _materialIcons) icon.codePoint: icon,
};

/// The default resolver: [icon] when it names one of the common Material
/// icons this package knows as constants, else null (the tile then shows no
/// icon).
IconData? forgeMaterialIconFor(ForgeIconRef icon) {
  if (icon.fontFamily != 'MaterialIcons' || icon.fontPackage != null) {
    return null;
  }
  return _materialByCodePoint[icon.codePoint];
}
