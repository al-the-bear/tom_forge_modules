/// Forge module for editing and driving `enterprise_flutter_web` websites.
///
/// Wraps the pure-Dart `tom_website_editor_core` (config + placeholders +
/// registry) in a [WebsiteEditorModule] that contributes the active-website
/// selection / reload config panel to the forge shell (§9.2). The preview and
/// control views (§9.3/§9.4) build on the shared [WebsiteEditorController].
library;

export 'src/website_config_panel.dart';
export 'src/website_editor_controller.dart';
export 'src/website_editor_module.dart';
