# Changelog

## 0.1.0

- The ZetaOffice office adapter, moved out of `tom_forge_office_editors`
  (split by route, R6): `ForgeZetaOfficeModule` (a kit module, no shell; opens a
  file itself when the file-type default names `office.zetaoffice`, or with
  `opensByDefault`), `ForgeZetaOfficeEditor` over `tom_office_zetaoffice`,
  `ForgeZetaOfficeHost`, `ForgeZetaOfficeKind`, `kForgeZetaOfficeDebug` (`[FZO]`).
- The office routes' evaluation harness moved here (`tool/evaluation/`), onto
  `tom_office_zetaoffice`.
