/// Forge's LibreOfficeKit office adapter: [ForgeOfficeLokModule], a kit
/// module that opens office files in [ForgeOfficeEditor] (LibreOfficeKit,
/// `office.lok`, the default) over [ForgeOfficeHost], offers it under Open
/// With and contributes [ForgeLibreOfficeTool], LibreOffice's row in External
/// Tools; another route (ZetaOffice) joins it as a
/// [ForgeOfficeAlternativeRoute]. Desktop only (a helper process). No
/// webview, no shell.
library;

export 'src/forge_office_editor.dart';
export 'src/forge_office_host.dart';
export 'src/forge_office_kind.dart';
export 'src/forge_office_trail.dart' show kForgeOfficeDebug;
export 'src/libreoffice_tool.dart';
export 'src/office_lok_module.dart';
// What the module's `detect` answers, for a host or test giving its own.
export 'package:tom_office_editor/tom_office_editor.dart'
    show LibreOfficeInstallation, LibreOfficeState;
