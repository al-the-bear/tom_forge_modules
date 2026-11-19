/// The office editors as Forge editor types: [ForgeOfficeEditorsModule]
/// opens office files and offers [ForgeOfficeEditor] (LibreOfficeKit,
/// `office.lok`, the default) and [ForgeZetaOfficeEditor] (ZetaOffice in a
/// webview, `office.zetaoffice`) under Open With, over [ForgeOfficeHost];
/// [ForgeLibreOfficeTool] is LibreOffice's row in External Tools. Desktop
/// only (a helper process, a local server).
library;

export 'src/forge_office_editor.dart';
export 'src/forge_office_host.dart';
export 'src/forge_office_kind.dart';
export 'src/forge_office_trail.dart' show kForgeOfficeDebug;
export 'src/forge_zetaoffice_editor.dart';
export 'src/libreoffice_tool.dart';
export 'src/office_editors_module.dart';
