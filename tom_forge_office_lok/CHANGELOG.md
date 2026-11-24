# Changelog

## 0.1.0

- The LibreOfficeKit office adapter, moved out of `tom_forge_office_editors`
  (split by route, R6): `ForgeOfficeLokModule` (a kit module: `activate(ForgeKitApi)`,
  no shell), `ForgeOfficeEditor`, `ForgeOfficeHost` (over `ForgeKitApi`),
  `ForgeOfficeKind`, `ForgeLibreOfficeTool` (contributed as the kit's
  `ForgeExternalToolsExtra`), `kForgeOfficeDebug`.
- Another route joins as `ForgeOfficeAlternativeRoute` (the missing-LibreOffice
  panel's button, the file-type default, its open editors); what the kit has no
  port for is given: `preferences`, `openExternal`, `filePickers`, `windowFocus`.
