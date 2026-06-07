/// Pure-Dart core for the `tom_website_editor` forge module.
///
/// Loads and validates `tom.website-editor.yaml` (§2) and resolves the
/// `{placeholder}` templates it contains (§3). The field-spec model is the
/// single source of truth from which both the runtime validator and the
/// published JSON Schema are derived (§6).
library;

export 'src/config/config_issue.dart';
export 'src/config/config_loader.dart';
export 'src/config/config_schema.dart';
export 'src/config/config_validator.dart';
export 'src/config/field_spec.dart';
export 'src/model/website_editor_config.dart';
export 'src/placeholder/placeholder_exception.dart';
export 'src/placeholder/placeholder_resolver.dart';
export 'src/registry/website_registry.dart';
