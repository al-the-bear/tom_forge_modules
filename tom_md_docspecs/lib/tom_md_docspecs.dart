/// DocSpecs schemas for the Markdown editor (`tom_md_editor`): validation,
/// typed sections with their templates, ids and tags, scaffolding and
/// for-each sync, forms for form-type sections, and the schema's panels —
/// through `tom_doc_specs` and `tom_doc_scanner`.
///
/// The entry point is [MdDocSpecsEditing.setSchema] on the editor's
/// controller (`controller.setSchema(schema)`), which attaches the schema as
/// the controller's schema support ([MdDocSpecsSupport]). Importing the
/// package registers nothing; a controller without a schema shows the
/// document as plain Markdown.
library;

export 'src/md_docspecs_editing.dart';
export 'src/md_docspecs_support.dart';
export 'src/validation/md_schema_validator.dart';
export 'src/validation/schema_section_helper.dart';
export 'src/validation/schema_template_helper.dart';
export 'src/widgets/md_char_counter.dart';
export 'src/widgets/md_for_each_sync_banner.dart';
export 'src/widgets/md_form_editor.dart';
export 'src/widgets/md_quick_fix_menu.dart';
export 'src/widgets/md_schema_info_panel.dart';
export 'src/widgets/md_schema_picker.dart';
export 'src/widgets/md_validation_prompt_banner.dart';
