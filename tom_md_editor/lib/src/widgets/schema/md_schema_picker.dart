import 'package:flutter/material.dart';
import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;

import '../../theme/md_editor_theme.dart';

/// A dialog-based schema picker that shows available schemas with a preview
/// of their structure (section count, form types, etc.).
///
/// Returns the selected [specs.DocSpecSchema] or `null` if cancelled.
///
/// ```dart
/// final schema = await MdSchemaPicker.show(
///   context: context,
///   schemas: availableSchemas,
///   theme: editorTheme,
/// );
/// ```
class MdSchemaPicker extends StatefulWidget {
  const MdSchemaPicker({
    super.key,
    required this.schemas,
    required this.theme,
    this.currentSchemaId,
  });

  /// Available schemas to choose from.
  final List<specs.DocSpecSchema> schemas;

  /// Editor theme.
  final MdEditorTheme theme;

  /// Currently active schema ID (highlighted in the list).
  final String? currentSchemaId;

  /// Show the picker dialog and return the selected schema.
  static Future<specs.DocSpecSchema?> show({
    required BuildContext context,
    required List<specs.DocSpecSchema> schemas,
    required MdEditorTheme theme,
    String? currentSchemaId,
  }) {
    return showDialog<specs.DocSpecSchema>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 480,
          height: 520,
          child: MdSchemaPicker(
            schemas: schemas,
            theme: theme,
            currentSchemaId: currentSchemaId,
          ),
        ),
      ),
    );
  }

  @override
  State<MdSchemaPicker> createState() => _MdSchemaPickerState();
}

class _MdSchemaPickerState extends State<MdSchemaPicker> {
  specs.DocSpecSchema? _selected;
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;
    final filtered = _filter.isEmpty
        ? widget.schemas
        : widget.schemas.where((s) {
            final q = _filter.toLowerCase();
            return s.id.toLowerCase().contains(q) ||
                s.version.toLowerCase().contains(q);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: basic.surface,
            border: Border(bottom: BorderSide(color: basic.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Schema',
                style: TextStyle(
                  color: basic.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                style: TextStyle(color: basic.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Filter schemas...',
                  hintStyle: TextStyle(color: basic.textMuted, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: basic.textMuted),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(basic.borderRadius),
                  ),
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ],
          ),
        ),

        // Schema list + preview
        Expanded(
          child: Row(
            children: [
              // List
              SizedBox(
                width: 200,
                child: ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (ctx, i) {
                    final schema = filtered[i];
                    final isCurrent =
                        schema.fullId == widget.currentSchemaId;
                    final isSelected = identical(schema, _selected);
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor:
                          basic.accent.withValues(alpha: 0.1),
                      title: Text(
                        schema.id,
                        style: TextStyle(
                          color: isSelected ? basic.accent : basic.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'v${schema.version}',
                        style: TextStyle(
                          color: basic.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      trailing: isCurrent
                          ? Icon(Icons.check_circle,
                              size: 16, color: basic.accent)
                          : null,
                      onTap: () =>
                          setState(() => _selected = schema),
                    );
                  },
                ),
              ),

              // Divider
              VerticalDivider(width: 1, color: basic.border),

              // Preview
              Expanded(
                child: _selected != null
                    ? _buildPreview(_selected!, basic)
                    : Center(
                        child: Text(
                          'Select a schema to preview',
                          style: TextStyle(
                            color: basic.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: basic.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _selected != null
                    ? () => Navigator.of(context).pop(_selected)
                    : null,
                child: const Text('Select'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(specs.DocSpecSchema schema, MdBasicTheme basic) {
    final sectionCount = schema.document.sections.length;
    final typeCount = schema.sectionTypes.length;
    final formCount = schema.formTypes?.length ?? 0;
    final tagCount = schema.customTags.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            schema.fullId,
            style: TextStyle(
              color: basic.accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _statChip('Sections', '$sectionCount', Icons.list, basic),
              _statChip('Types', '$typeCount', Icons.category, basic),
              if (formCount > 0)
                _statChip('Forms', '$formCount', Icons.edit_note, basic),
              if (tagCount > 0)
                _statChip('Tags', '$tagCount', Icons.label, basic),
            ],
          ),
          const SizedBox(height: 16),

          // Document sections
          Text(
            'Document Structure',
            style: TextStyle(
              color: basic.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...schema.document.sections.entries.map((e) {
            final optional = e.value.optional ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    optional
                        ? Icons.check_box_outline_blank
                        : Icons.check_box,
                    size: 14,
                    color: optional ? basic.textMuted : basic.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.key,
                    style: TextStyle(color: basic.text, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${e.value.sectionType})',
                    style: TextStyle(
                      color: basic.textMuted,
                      fontSize: 11,
                      fontFamily: basic.monoFontFamily,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Section types
          if (schema.sectionTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Section Types',
              style: TextStyle(
                color: basic.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...schema.sectionTypes.entries.map((e) {
              final desc = e.value.description;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.code, size: 14, color: basic.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: e.key,
                            style: TextStyle(
                              color: basic.text,
                              fontSize: 12,
                              fontFamily: basic.monoFontFamily,
                            ),
                          ),
                          if (desc != null)
                            TextSpan(
                              text: ' — $desc',
                              style: TextStyle(
                                color: basic.textMuted,
                                fontSize: 11,
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _statChip(
    String label,
    String value,
    IconData icon,
    MdBasicTheme basic,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: basic.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: basic.accent),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: TextStyle(
              color: basic.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
