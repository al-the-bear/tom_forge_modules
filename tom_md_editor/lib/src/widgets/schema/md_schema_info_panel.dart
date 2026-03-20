import 'package:flutter/material.dart';
import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;

import '../../theme/md_editor_theme.dart';

/// Collapsible panel showing schema metadata: section types, form types,
/// custom tags, and constraints.
///
/// Provides users with a browsable reference without needing to open
/// the raw YAML schema file.
class MdSchemaInfoPanel extends StatefulWidget {
  const MdSchemaInfoPanel({
    super.key,
    required this.schema,
    required this.theme,
  });

  final specs.DocSpecSchema schema;
  final MdEditorTheme theme;

  @override
  State<MdSchemaInfoPanel> createState() => _MdSchemaInfoPanelState();
}

class _MdSchemaInfoPanelState extends State<MdSchemaInfoPanel> {
  bool _expanded = false;
  String? _expandedType;

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;

    return Container(
      decoration: BoxDecoration(
        color: basic.surface,
        border: Border(
          bottom: BorderSide(color: basic.border, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.schema,
                    size: 14,
                    color: basic.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.schema.fullId,
                    style: TextStyle(
                      color: basic.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.schema.sectionTypes.length} types',
                    style: TextStyle(
                      color: basic.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: basic.textMuted,
                  ),
                ],
              ),
            ),
          ),
          // Body
          if (_expanded) _buildBody(basic),
        ],
      ),
    );
  }

  Widget _buildBody(MdBasicTheme basic) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document structure
            _buildSectionHeader('Document Structure', basic),
            _buildDocumentSections(basic),
            const SizedBox(height: 8),
            // Section types
            _buildSectionHeader(
              'Section Types (${widget.schema.sectionTypes.length})',
              basic,
            ),
            ...widget.schema.sectionTypes.entries
                .map((e) => _buildTypeDef(e.key, e.value, basic)),
            // Form types
            if (widget.schema.formTypes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              _buildSectionHeader(
                'Form Types (${widget.schema.formTypes!.length})',
                basic,
              ),
              ...widget.schema.formTypes!.entries
                  .map((e) => _buildFormType(e.key, e.value, basic)),
            ],
            // Custom tags
            if (widget.schema.customTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSectionHeader('Custom Tags', basic),
              _buildCustomTags(basic),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, MdBasicTheme basic) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          color: basic.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDocumentSections(MdBasicTheme basic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.schema.document.sections.entries.map((entry) {
        final optional = entry.value.optional ?? false;
        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Row(
            children: [
              Icon(
                optional ? Icons.check_box_outline_blank : Icons.check_box,
                size: 12,
                color: optional ? basic.textMuted : basic.accent,
              ),
              const SizedBox(width: 4),
              Text(
                entry.key,
                style: TextStyle(
                  color: basic.text,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '→ ${entry.value.sectionType}',
                style: TextStyle(
                  color: basic.textMuted,
                  fontSize: 11,
                  fontFamily: basic.monoFontFamily,
                ),
              ),
              if (optional)
                Text(
                  ' (optional)',
                  style: TextStyle(
                    color: basic.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeDef(
    String name,
    specs.SectionTypeDef typeDef,
    MdBasicTheme basic,
  ) {
    final isExpanded = _expandedType == name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedType = isExpanded ? null : name;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: basic.textMuted,
                ),
                const SizedBox(width: 2),
                Text(
                  name,
                  style: TextStyle(
                    color: basic.text,
                    fontSize: 12,
                    fontFamily: basic.monoFontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (typeDef.prefix != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: basic.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      typeDef.prefix!,
                      style: TextStyle(
                        color: basic.accent,
                        fontSize: 10,
                        fontFamily: basic.monoFontFamily,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isExpanded) _buildTypeDetails(typeDef, basic),
      ],
    );
  }

  Widget _buildTypeDetails(specs.SectionTypeDef typeDef, MdBasicTheme basic) {
    final details = <Widget>[];

    if (typeDef.description != null) {
      details.add(_detailRow('Description', typeDef.description!, basic));
    }
    if (typeDef.format != null) {
      details.add(_detailRow('Format', typeDef.format!, basic));
    }
    if (typeDef.maxCountInDocument != null) {
      details.add(_detailRow(
        'Max in doc',
        typeDef.maxCountInDocument.toString(),
        basic,
      ));
    }
    if (typeDef.maxSubsectionLevels != null) {
      details.add(_detailRow(
        'Max child levels',
        typeDef.maxSubsectionLevels.toString(),
        basic,
      ));
    }
    if (typeDef.textRequired ?? false) {
      var constraint = 'Required';
      if (typeDef.minTextLength != null) {
        constraint += ', min ${typeDef.minTextLength} chars';
      }
      if (typeDef.maxTextLength != null) {
        constraint += ', max ${typeDef.maxTextLength} chars';
      }
      details.add(_detailRow('Text', constraint, basic));
    }
    if (typeDef.patternCheckId != null) {
      details.add(_detailRow(
        'ID pattern',
        typeDef.patternCheckId!.pattern,
        basic,
        mono: true,
      ));
    }
    if (typeDef.patternCheckText != null) {
      details.add(_detailRow(
        'Text pattern',
        typeDef.patternCheckText!.pattern,
        basic,
        mono: true,
      ));
    }
    if (typeDef.allowedTags != null) {
      details.add(_detailRow(
        'Allowed tags',
        typeDef.allowedTags!.join(', '),
        basic,
      ));
    }
    if (typeDef.requiredFields != null) {
      details.add(_detailRow(
        'Required fields',
        typeDef.requiredFields!.join(', '),
        basic,
      ));
    }
    if (typeDef.subsectionTypes != null) {
      final children = typeDef.subsectionTypes!.keys.join(', ');
      details.add(_detailRow('Children', children, basic));
    }

    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details,
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    MdBasicTheme basic, {
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: basic.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: basic.text,
                fontSize: 11,
                fontFamily: mono ? basic.monoFontFamily : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormType(
    String name,
    specs.FormTypeDef formType,
    MdBasicTheme basic,
  ) {
    final fields =
        formType.fields.map((f) => f.fieldname).join(', ');
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: name,
              style: TextStyle(
                color: basic.text,
                fontSize: 12,
                fontFamily: basic.monoFontFamily,
              ),
            ),
            TextSpan(
              text: ': $fields',
              style: TextStyle(
                color: basic.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTags(MdBasicTheme basic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.schema.customTags.entries.map((entry) {
        String valueStr;
        if (entry.value is List) {
          valueStr = (entry.value as List).join(', ');
        } else if (entry.value is Map) {
          valueStr = (entry.value as Map).keys.join(', ');
        } else {
          valueStr = entry.value.toString();
        }
        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: entry.key,
                  style: TextStyle(
                    color: basic.text,
                    fontSize: 12,
                    fontFamily: basic.monoFontFamily,
                  ),
                ),
                TextSpan(
                  text: ': $valueStr',
                  style: TextStyle(
                    color: basic.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
