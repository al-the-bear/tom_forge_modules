import 'package:flutter/material.dart';

/// Dialog for editing a section's headline, ID, and comment metadata.
///
/// Displays headline and ID fields (with optional prefix autocomplete),
/// plus one text field per metadata key.  Metadata keys come from:
///  - existing `commentMetadata` on the section
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
  });

  final TextEditingController headlineController;
  final TextEditingController idController;
  final Map<String, TextEditingController> metaControllers;
  final List<String> prefixSuggestions;
  final String? patternHint;
  final List<String> schemaFields;

  @override
  State<EditSectionDialog> createState() => _EditSectionDialogState();
}

class _EditSectionDialogState extends State<EditSectionDialog> {
  final _newKeyController = TextEditingController();

  @override
  void dispose() {
    _newKeyController.dispose();
    super.dispose();
  }

  void _addMetadataField() {
    final key = _newKeyController.text.trim();
    if (key.isEmpty || widget.metaControllers.containsKey(key)) return;
    setState(() {
      widget.metaControllers[key] = TextEditingController();
      _newKeyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.5);

    return AlertDialog(
      title: const Text('Edit Section'),
      content: SizedBox(
        width: 360,
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
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
