// Tom Markdown Editor — a Flutter widget for structured markdown editing.
//
// Provides tree navigation, formatted preview, raw text editing,
// undo/redo, search/replace, and configurable theming.

// Constants
export 'src/constants/md_constants.dart';

// Debug
export 'src/debug/md_editor_debug.dart';

// Models
export 'src/models/md_document.dart';
export 'src/models/md_parser.dart';
export 'src/models/md_search_result.dart';
export 'src/models/md_section.dart';

// Providers
export 'src/providers/asset_document_provider.dart';
export 'src/providers/file_document_provider.dart';
export 'src/providers/http_document_provider.dart';
export 'src/providers/md_document_provider.dart';

// Registries
export 'src/registries/md_code_editor_registry.dart';
export 'src/registries/md_content_renderer.dart';
export 'src/registries/md_language_renderer_registry.dart';

// Plugins
export 'src/plugins/md_content_plugin.dart';
export 'src/plugins/md_code_plugin.dart';
export 'src/plugins/md_default_plugins.dart';
export 'src/plugins/md_math_plugin.dart';
export 'src/plugins/md_mermaid_plugin.dart';
export 'src/plugins/md_table_plugin.dart';

// Events
export 'src/events/md_events.dart';

// Settings
export 'src/settings/md_editor_settings.dart';

// Theme
export 'src/theme/md_editor_theme.dart';

// Controller
export 'src/controller/md_editor_controller.dart';

// Widgets
export 'src/widgets/md_editor.dart';
export 'src/widgets/preview/md_preview_panel.dart';
export 'src/widgets/raw_editor/md_raw_text_editor.dart';
export 'src/widgets/tree/md_search_panel.dart';
export 'src/widgets/tree/md_tree_view.dart';

// Toolbar & Status Bar
export 'src/widgets/toolbar/md_editor_toolbar.dart';
export 'src/widgets/status_bar/md_editor_status_bar.dart';

// Overlays
export 'src/widgets/overlays/md_code_block_overlay.dart';

// Schema Widgets
export 'src/widgets/schema/md_char_counter.dart';
export 'src/widgets/schema/md_for_each_sync_banner.dart';
export 'src/widgets/schema/md_form_editor.dart';
export 'src/widgets/schema/md_quick_fix_menu.dart';
export 'src/widgets/schema/md_schema_info_panel.dart';
export 'src/widgets/schema/md_schema_picker.dart';
export 'src/widgets/schema/md_validation_prompt_banner.dart';

// Validation
export 'src/validation/md_schema_validator.dart';
export 'src/validation/schema_section_helper.dart';
export 'src/validation/schema_template_helper.dart';
export 'src/widgets/overlays/md_math_overlay.dart';
export 'src/widgets/overlays/md_mermaid_overlay.dart';
export 'src/widgets/overlays/md_table_overlay.dart';

// Renderers
export 'src/widgets/renderers/md_math_renderer.dart';
export 'src/widgets/renderers/md_mermaid_renderer.dart';

// Syntax Highlighting
export 'src/widgets/raw_editor/md_syntax_highlight_controller.dart';

// Integration
export 'src/integration/editor_trail.dart';
export 'src/integration/md_text_context.dart';
