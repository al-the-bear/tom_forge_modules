/// Forge's file explorer as a kit component: the workspace's file tree with
/// open, rename, new file and folder, delete and the modules' context-menu
/// entries ([ForgeFileExplorerView]), in any application on the kit,
/// contributed by [forgeFileExplorerModule]; opt-in filter rules with
/// presets, the hidden count and a switcher of registered roots.
library;

// The filter the explorer takes (tom_file_session's rule list and presets).
export 'package:tom_file_session/tom_file_session.dart'
    show
        ForgeBuiltInPresets,
        ForgeExtensionRule,
        ForgeFilter,
        ForgeFilterPreset,
        ForgeFilterRule,
        ForgeGitignoredRule,
        ForgeGlobRule,
        ForgeHiddenRule,
        ForgeTodoSiblingsRule;

export 'src/forge_explorer_settings.dart';
export 'src/forge_explorer_tree_walk.dart';
export 'src/forge_file_explorer_module.dart';
export 'src/forge_file_explorer_trail.dart';
export 'src/forge_file_explorer_view.dart';
