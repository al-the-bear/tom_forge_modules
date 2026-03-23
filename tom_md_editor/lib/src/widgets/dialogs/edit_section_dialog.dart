import 'package:flutter/material.dart';

/// Dialog for editing a section's headline, ID, tags, and comment metadata.
///
/// Displays headline and ID fields (with optional prefix autocomplete),
/// a tag editor with schema-allowed tags shown as filter chips,
/// plus one text field per metadata key.  Metadata keys come from:
///  - existing `commentMetadata` on the section (excluding 'tags')
///  - `requiredFields` declared by the schema for this section type
class EditSectionDialog extends StatefulWidget {
  const EditSectionDialog({
    super.key,
    required this.headlineController,
    required this.idController,
    required this.metaControllers,
    this.prefixSuggestions = const [],
    this.patternHint,
    this.schemaFields = const [],
    this.allowedTags = const [],
    this.initialTags = const [],
  });

  final TextEditingController headlineController;
  final TextEditingController idController;
  final Map<String, TextEditingController> metaControllers;
  final List<String> prefixSuggestions;
  final String? patternHint;
  final List<String> schemaFields;

  /// Tags allowed by the schema for this section type.
  /// If empty, any tags are allowed.
  final List<String> allowedTags;

  /// Initial tags from section's commentMetadata['tags'].
  final List<String> initialTags;

  @override
  State<EditSectionDialog> createState() => _EditSectionDialogState();
}

class _EditSectionDialogState extends State<EditSectionDialog> {
  final _newKeyController = TextEditingController();
  final _newTagController = TextEditingController();
  late List<String> _currentTags;

  @override
  void initState() {
    super.initState();
    _currentTags = List<String>.from(widget.initialTags);
  }

  @override
  void dispose() {
    _newKeyController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  void _addMetadataField() {
    final key = _newKeyController.text.trim();
    if (key.isEmpty || widget.metaControllers.containsKey(key)) return;
    if (key == 'tags') return; // Tags handled separately.
    setState(() {
      widget.metaControllers[key] = TextEditingController();
      _newKeyController.clear();
    });
  }

  void _addCustomTag() {
    final tag = _newTagController.text.trim();
    if (tag.isEmpty || _currentTags.contains(tag)) return;
    setState(() {
      _currentTags.add(tag);
      _newTagController.clear();
    });
  }

  /// Get semantic color for a tag based on its name.
  Color _tagColor(String tag, ColorScheme colorScheme) {
    final lower = tag.toLowerCase();
    if (lower == 'critical' || lower == 'error') return Colors.red;
    if (lower == 'high' || lower == 'warning') return Colors.orange;
    if (lower == 'medium' || lower == 'info') return Colors.blue;
    if (lower == 'low' || lower == 'minor') return Colors.green;
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.5);

    // Custom tags are tags not in allowedTags.
    final customTags = _currentTags
        .where((t) => !widget.allowedTags.contains(t))
        .toList();

    return AlertDialog(
      title: const Text('Edit Section'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // — Headline —
              TextField(
                controller: widget.headlineController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Headline'),
              ),
              const SizedBox(height: 12),

              // — ID —
              if (widget.prefixSuggestions.isNotEmpty)
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.toLowerCase();
                    if (query.isEmpty) return widget.prefixSuggestions;
                    return widget.prefixSuggestions.where(
                      (s) => s.toLowerCase().contains(query),
                    );
                  },
                  fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                    controller.text = widget.idController.text;
                    controller.addListener(() {
                      widget.idController.text = controller.text;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'ID (optional)',
                        hintText: 'e.g. my-section-id',
                        suffixIcon: Icon(
                          Icons.arrow_drop_down,
                          color: mutedColor,
                        ),
                      ),
                    );
                  },
                  onSelected: (value) {
                    widget.idController.text = value;
                  },
                )
              else
                TextField(
                  controller: widget.idController,
                  decoration: const InputDecoration(
                    labelText: 'ID (optional)',
                    hintText: 'e.g. my-section-id',
                  ),
                ),

              if (widget.patternHint != null &&
                  widget.patternHint!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Expected pattern: ${widget.patternHint}',
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              // — Tags —
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.label, size: 16, color: mutedColor),
                  const SizedBox(width: 6),
                  Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Allowed tags as filter chips.
              if (widget.allowedTags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.allowedTags.map((tag) {
                    final isSelected = _currentTags.contains(tag);
                    final color = _tagColor(tag, colorScheme);
                    return FilterChip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          color: isSelected ? Colors.white : color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: color.withValues(alpha: 0.8),
                      backgroundColor: color.withValues(alpha: 0.1),
                      checkmarkColor: Colors.white,
                      side: BorderSide(color: color.withValues(alpha: 0.4)),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _currentTags.add(tag);
                          } else {
                            _currentTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Custom tags (deletable chips).
              if (customTags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: customTags.map((tag) {
                    final color = _tagColor(tag, colorScheme);
                    return Chip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: color.withValues(alpha: 0.1),
                      side: BorderSide(color: color.withValues(alpha: 0.4)),
                      deleteIconColor: color,
                      onDeleted: () {
                        setState(() => _currentTags.remove(tag));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Add new tag field.
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTagController,
                      decoration: const InputDecoration(
                        hintText: 'Add tag...',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: 'Add tag',
                    onPressed: _addCustomTag,
                  ),
                ],
              ),

              // — Comment Metadata —
              if (widget.metaControllers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Comment Metadata',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in widget.metaControllers.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        isDense: true,
                        suffixIcon: widget.schemaFields.contains(entry.key)
                            ? Tooltip(
                                message: 'Required by schema',
                                child: Icon(
                                  Icons.star,
                                  size: 14,
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.6),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],

              // — Add new metadata field —
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newKeyController,
                      decoration: const InputDecoration(
                        labelText: 'New field name',
                        isDense: true,
                        hintText: 'e.g. priority',
                      ),
                      onSubmitted: (_) => _addMetadataField(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: 'Add metadata field',
                    onPressed: _addMetadataField,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _currentTags),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
