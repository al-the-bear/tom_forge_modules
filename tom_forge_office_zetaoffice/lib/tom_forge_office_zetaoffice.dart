/// Forge's ZetaOffice office adapter: [ForgeZetaOfficeModule], a kit module
/// that offers [ForgeZetaOfficeEditor] (ZetaOffice in a webview,
/// `office.zetaoffice`, the comparison route) under Open With over
/// [ForgeZetaOfficeHost], and opens an office file itself when the file-type
/// default names it. Desktop only (a webview, a local server). No shell.
library;

export 'src/forge_zetaoffice_editor.dart';
export 'src/forge_zetaoffice_host.dart';
export 'src/forge_zetaoffice_kind.dart';
export 'src/forge_zetaoffice_trail.dart' show kForgeZetaOfficeDebug;
export 'src/zetaoffice_module.dart';
