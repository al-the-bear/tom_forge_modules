import 'package:flutter/material.dart';

/// Information about a section type allowed at the current location.
typedef SectionTypeInfo = ({
  String typeName,
  String prefix,
  String? idPattern,
  String? idPatternErrorMessage,
});

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
    this.allowedSectionTypes = const [],
    this.hasSchema = false,
    this.schemaFields = const [],
    this.allowedTags = const [],
    this.initialTags = const [],
  });

  final TextEditingController headlineController;
  final TextEditingController idController;
  final Map<String, TextEditingController> metaControllers;

  /// Section types allowed at this location (context-sensitive).
  /// Each entry contains typeName, prefix, idPattern, and error message.
  final List<SectionTypeInfo> allowedSectionTypes;

  /// Whether schema mode is active. If false, only shows free-text ID field.
  final bool hasSchema;

  /// Schema-required metadata fields for this section type.
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
  final _idSuffixController = TextEditingController();
  late List<String> _currentTags;
  String? _selectedPrefix;

  @override
  void initState() {
    super.initState();
    _currentTags = List<String>.from(widget.initialTags);
    _initializeIdParts();
  }

  void _initializeIdParts() {
    // Parse existing ID into prefix + suffix.
    final existingId = widget.idController.text;
    if (existingId.isEmpty || widget.allowedSectionTypes.isEmpty) {
      _selectedPrefix = null;
      _idSuffixController.text = existingId;
      return;
    }

    // Try to match a known prefix.
    for (final typeInfo in widget.allowedSectionTypes) {
      final prefix = typeInfo.prefix;
      if (existingId == prefix) {
        _selectedPrefix = prefix;
        _idSuffixController.text = '';
        return;
      }
      // Check if ID starts with prefix followed by separator (-, ., _).
      if (existingId.startsWith(prefix)) {
        final rest = existingId.substring(prefix.length);
        if (rest.isEmpty || rest.startsWith('-') || rest.startsWith('.') || rest.startsWith('_')) {
          _selectedPrefix = prefix;
          _idSuffixController.text = rest;
          return;
        }
      }
    }

    // No prefix match - use first available or null.
    _selectedPrefix = widget.allowedSectionTypes.isNotEmpty
        ? widget.allowedSectionTypes.first.prefix
        : null;
    _idSuffixController.text = existingId;
  }

  String get _completeId {
    if (_selectedPrefix == null || _selectedPrefix!.isEmpty) {
      return _idSuffixController.text;
    }
    return '$_selectedPrefix${_idSuffixController.text}';
  }

  void _updateIdController() {
    widget.idController.text = _completeId;
  }

  /// Get validation status for current ID.
  ({bool isValid, String? errorMessage}) _validateId() {
    if (widget.allowedSectionTypes.isEmpty) {
      return (isValid: true, errorMessage: null);
    }

    final id = _completeId;
    if (id.isEmpty) {
      return (isValid: true, errorMessage: null); // Empty ID is okay.
    }

    // Find the section type matching the selected prefix.
    final typeInfo = widget.allowedSectionTypes
        .where((t) => t.prefix == _selectedPrefix)
        .firstOrNull;

    if (typeInfo == null) {
      return (isValid: false, errorMessage: 'No matching section type');
    }

    final pattern = typeInfo.idPattern;
    if (pattern == null || pattern.isEmpty) {
      return (isValid: true, errorMessage: null); // No pattern = any ID okay.
    }

    try {
      final regex = RegExp(pattern);
      if (regex.hasMatch(id)) {
        return (isValid: true, errorMessage: null);
      }
      return (
        isValid: false,
        errorMessage: typeInfo.idPatternErrorMessage ?? 'Pattern: $pattern',
      );
    } catch (e) {
      return (isValid: false, errorMessage: 'Invalid regex: $pattern');
    }
  }

  @override
  void dispose() {
    _newKeyController.dispose();
    _newTagController.dispose();
    _idSuffixController.dispose();
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
        width: 420,
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
              _buildIdEditor(colorScheme, mutedColor),

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

              // Custom tags (deletable chips) - only shown when no allowed tags.
              if (widget.allowedTags.isEmpty && customTags.isNotEmpty) ...[
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

              // Add tag: dropdown if allowedTags, free-text otherwise.
              if (widget.allowedTags.isNotEmpty) ...[
                // Dropdown for unselected allowed tags.
                Builder(builder: (context) {
                  final unselected = widget.allowedTags
                      .where((t) => !_currentTags.contains(t))
                      .toList();
                  if (unselected.isEmpty) {
                    return Text(
                      'All allowed tags selected',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: mutedColor,
                      ),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Add tag',
                      isDense: true,
                    ),
                    hint: const Text('Select tag to add'),
                    items: unselected.map((tag) {
                      final color = _tagColor(tag, colorScheme);
                      return DropdownMenuItem(
                        value: tag,
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (tag) {
                      if (tag != null && !_currentTags.contains(tag)) {
                        setState(() => _currentTags.add(tag));
                      }
                    },
                  );
                }),
              ] else ...[
                // Free-text field when no allowed tags defined.
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
          onPressed: () => Navigator.pop(context, _currentTags),
          child: const Text('Save'),
        ),
      ],
    );
  }

  /// Build the ID editor with split prefix + suffix when in schema mode.
  Widget _buildIdEditor(ColorScheme colorScheme, Color mutedColor) {
    // No schema mode - just a free-text field.
    if (!widget.hasSchema) {
      return TextField(
        controller: widget.idController,
        decoration: const InputDecoration(
          labelText: 'ID (optional)',
          hintText: 'e.g. my-section-id',
        ),
      );
    }

    // Schema mode with no allowed types - just show free-text.
    if (widget.allowedSectionTypes.isEmpty) {
      return TextField(
        controller: widget.idController,
        decoration: const InputDecoration(
          labelText: 'ID (optional)',
          hintText: 'e.g. my-section-id',
        ),
      );
    }

    // Schema mode with allowed types - split prefix dropdown + suffix.
    final validation = _validateId();
    final completeId = _completeId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prefix dropdown.
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Type Prefix',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                value: _selectedPrefix,
                items: widget.allowedSectionTypes.map((typeInfo) {
                  return DropdownMenuItem(
                    value: typeInfo.prefix,
                    child: Text(
                      typeInfo.prefix,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPrefix = value;
                    _updateIdController();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            // Suffix text field.
            Expanded(
              child: TextField(
                controller: _idSuffixController,
                decoration: const InputDecoration(
                  labelText: 'ID Suffix',
                  isDense: true,
                  hintText: '-001 or .my-section',
                ),
                onChanged: (_) {
                  setState(() {
                    _updateIdController();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            // Validation indicator.
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: validation.isValid
                  ? Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.green[600],
                    )
                  : Tooltip(
                      message: validation.errorMessage ?? 'Invalid ID format',
                      child: Icon(
                        Icons.error,
                        size: 20,
                        color: Colors.red[600],
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Complete ID preview.
        if (completeId.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: validation.isValid
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: validation.isValid
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Complete ID: ',
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    completeId,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: validation.isValid
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
