import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../schema/yaml_schema.dart';
import '../yaml_editor_theme.dart';

/// Initial value type selected in the add-key / add-item dialog.
///
/// Exposed publicly so the dialog can be reused from context menus and
/// action buttons without duplicating code.
enum AddKeyType {
  string,
  boolean,
  integer,
  float,
  map,
  list,
  nullValue;

  Object? toValue() => switch (this) {
        AddKeyType.string => '',
        AddKeyType.boolean => false,
        AddKeyType.integer => 0,
        AddKeyType.float => 0.0,
        AddKeyType.map => <String, Object>{},
        AddKeyType.list => <Object>[],
        AddKeyType.nullValue => null,
      };

  String get label => switch (this) {
        AddKeyType.string => 'String',
        AddKeyType.boolean => 'Bool',
        AddKeyType.integer => 'Int',
        AddKeyType.float => 'Float',
        AddKeyType.map => 'Map',
        AddKeyType.list => 'List',
        AddKeyType.nullValue => 'Null',
      };
}

/// Shows the shared add-key dialog: asks for a key name, initial value type,
/// and (for scalar types) an initial value.
///
/// When [parentSchema] is provided:
/// * Suggested keys from the schema are shown as chips for quick selection.
/// * Selecting a chip auto-populates the key field and pre-selects its type.
/// * Typing a key that matches a schema property auto-switches the type.
///
/// Returns `null` if the user cancels or enters an empty key name.
Future<({String key, Object? value})?> showAddKeyDialog(
  BuildContext context, {
  SchemaNode? parentSchema,
}) async {
  final keyCtrl = TextEditingController();
  final valCtrl = TextEditingController();
  var selectedType = AddKeyType.string;
  var boolValue = false;
  String? valueError;

  // Suggested keys from schema (caller passes the schema for the parent map).
  final suggestedKeys = parentSchema?.properties.entries.toList() ?? [];

  final result = await showDialog<({String key, Object? value})>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(builder: (ctx, setDs) {
        // Default text for the value field based on type.
        String defaultValText(AddKeyType t) => switch (t) {
              AddKeyType.integer => '0',
              AddKeyType.float => '0.0',
              _ => '',
            };

        // Compute the actual initial value to return.
        Object? computeValue() => switch (selectedType) {
              AddKeyType.string => valCtrl.text,
              AddKeyType.integer => int.tryParse(valCtrl.text) ?? 0,
              AddKeyType.float =>
                double.tryParse(valCtrl.text) ?? 0.0,
              AddKeyType.boolean => boolValue,
              AddKeyType.map => <String, Object>{},
              AddKeyType.list => <Object>[],
              AddKeyType.nullValue => null,
            };

        // Validate value field; returns error string or null.
        String? validateValue() {
          switch (selectedType) {
            case AddKeyType.integer:
              if (int.tryParse(valCtrl.text) == null) {
                return 'Must be a whole number (e.g. 0, 42, \u221242). '
                    'Decimals and other characters are not allowed.';
              }
            case AddKeyType.float:
              if (double.tryParse(valCtrl.text) == null) {
                return 'Must be a number (e.g. 0.0, 3.14, \u22120.5, 1e10). '
                    'Only digits, a dot and a leading minus are allowed.';
              }
            default:
              break;
          }
          return null;
        }

        // Auto-select type when key matches a schema property.
        void onKeyChanged(String key) {
          if (parentSchema == null) return;
          final prop = parentSchema.properties[key];
          if (prop == null) return;
          final auto = _schemaTypeToAddKeyType(prop.type);
          if (auto != selectedType) {
            setDs(() {
              selectedType = auto;
              valCtrl.text = defaultValText(auto);
              boolValue = false;
              valueError = null;
            });
          }
        }

        return AlertDialog(
          title: const Text('Add key'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Schema suggestion chips
                if (suggestedKeys.isNotEmpty) ...[
                  Text(
                    'Schema suggestions:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestedKeys.map((e) {
                      final chipType =
                          _schemaTypeToAddKeyType(e.value.type);
                      return ActionChip(
                        label: Text(
                          e.key,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => setDs(() {
                          keyCtrl.text = e.key;
                          selectedType = chipType;
                          valCtrl.text = defaultValText(chipType);
                          boolValue = false;
                          valueError = null;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                ],
                // Key name field
                TextField(
                  controller: keyCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Key name',
                    hintText: 'new-key',
                  ),
                  onChanged: onKeyChanged,
                  onSubmitted: (v) {
                    final k = v.trim();
                    if (k.isEmpty) return;
                    final err = validateValue();
                    if (err != null) {
                      setDs(() => valueError = err);
                      return;
                    }
                    Navigator.of(dialogCtx)
                        .pop((key: k, value: computeValue()));
                  },
                ),
                const SizedBox(height: 16),
                // Type dropdown
                InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Initial value type'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AddKeyType>(
                      value: selectedType,
                      isDense: true,
                      items: AddKeyType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ))
                          .toList(),
                      onChanged: (t) => setDs(() {
                        selectedType = t!;
                        valCtrl.text = defaultValText(t);
                        boolValue = false;
                        valueError = null;
                      }),
                    ),
                  ),
                ),
                // Initial value input for scalars
                if (selectedType == AddKeyType.string ||
                    selectedType == AddKeyType.integer ||
                    selectedType == AddKeyType.float) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: valCtrl,
                    decoration: InputDecoration(
                      labelText: 'Initial value',
                      hintText: switch (selectedType) {
                        AddKeyType.integer => '0',
                        AddKeyType.float => '0.0',
                        _ => '',
                      },
                      errorText: valueError,
                      errorMaxLines: 3,
                    ),
                    keyboardType: selectedType == AddKeyType.string
                        ? TextInputType.multiline
                        : const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                    inputFormatters: switch (selectedType) {
                      AddKeyType.integer => [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\-]'))
                        ],
                      AddKeyType.float => [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.\-eE]'))
                        ],
                      _ => [],
                    },
                    maxLines: selectedType == AddKeyType.string ? null : 1,
                    minLines: 1,
                    onChanged: (_) {
                      if (valueError != null) setDs(() => valueError = null);
                    },
                  ),
                ],
                if (selectedType == AddKeyType.boolean) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Initial value',
                          style: TextStyle(fontSize: 13)),
                      const Spacer(),
                      Switch(
                        value: boolValue,
                        onChanged: (v) => setDs(() => boolValue = v),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final k = keyCtrl.text.trim();
                if (k.isEmpty) return;
                final err = validateValue();
                if (err != null) {
                  setDs(() => valueError = err);
                  return;
                }
                Navigator.of(dialogCtx).pop((key: k, value: computeValue()));
              },
              child: const Text('Add'),
            ),
          ],
        );
      });
    },
  );

  final key = result?.key.trim() ?? '';
  if (key.isEmpty) return null;
  return (key: key, value: result!.value);
}

/// Map a [SchemaType] to the closest [AddKeyType].
AddKeyType _schemaTypeToAddKeyType(SchemaType schemaType) =>
    switch (schemaType) {
      SchemaType.string => AddKeyType.string,
      SchemaType.integer => AddKeyType.integer,
      SchemaType.number => AddKeyType.float,
      SchemaType.boolean => AddKeyType.boolean,
      SchemaType.object => AddKeyType.map,
      SchemaType.array => AddKeyType.list,
    };

/// Row of action buttons for a YAML tree node.
///
/// Shows add/remove/inspect buttons based on:
/// - Schema suggestions (for add button).
/// - Whether the key is optional (for remove button).
/// - Theme toggle flags (`showAddButtons`, `showRemoveButtons`).
/// - Whether the editor is read-only.
///
/// ```dart
/// YamlNodeActions(
///   suggestedKeys: ['description', 'version'],
///   canRemove: true,
///   canInspect: true,
///   onAdd: (key) => controller.insertKey(path, key, null),
///   onRemove: () => controller.removeKey(path),
///   onInspect: () => openSubtreeInspector(path),
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class YamlNodeActions extends StatelessWidget {
  /// Keys that can be added (from schema suggestions).
  final List<String> suggestedKeys;

  /// Whether this node can be removed.
  final bool canRemove;

  /// Whether remove should stay visible even when [visible] is false.
  final bool alwaysShowRemove;

  /// Whether this node can be inspected as raw YAML.
  final bool canInspect;

  /// Callback when a schema-suggested key is added (key name only).
  final ValueChanged<String>? onAdd;

  /// Callback when a key is manually added with an explicit initial value
  /// type chosen by the user in the add-key dialog.
  final void Function(String key, Object? value)? onAddWithType;

  /// Callback for direct add actions (e.g. append list item).
  final VoidCallback? onAddItem;

  /// Tooltip used for [onAddItem] action.
  final String addItemTooltip;

  /// Callback when a list item is added via the type-picker popup.
  ///
  /// When provided, the add-item button shows a type-selection popup instead
  /// of calling [onAddItem] directly. The selected value (of the corresponding
  /// type) is passed as the argument.
  final ValueChanged<Object?>? onAddItemWithType;

  /// Schema node for the map that owns this node (for the add-key dialog).
  ///
  /// When provided, the dialog shows schema-suggested keys as chips and
  /// auto-selects the matching type when the user types or picks a key.
  final SchemaNode? parentSchemaNode;

  /// Schema node for the items of this list (for the add-item type picker).
  ///
  /// When provided and the schema mandates a type, the add-item button uses
  /// that type directly instead of showing the picker popup.
  final SchemaNode? itemsSchemaNode;

  /// Whether this node can be moved up within its parent container.
  final bool canMoveUp;

  /// Whether this node can be moved down within its parent container.
  final bool canMoveDown;

  /// Callback to move this node one position up.
  final VoidCallback? onMoveUp;

  /// Callback to move this node one position down.
  final VoidCallback? onMoveDown;

  /// Callback when this node is removed.
  final VoidCallback? onRemove;

  /// Callback to open the subtree inspector.
  final VoidCallback? onInspect;

  /// Whether the actions are visible.
  final bool visible;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Theme for styling.
  final YamlEditorTheme theme;

  const YamlNodeActions({
    super.key,
    this.suggestedKeys = const [],
    this.canRemove = false,
    this.alwaysShowRemove = false,
    this.canInspect = false,
    this.onAdd,
    this.onAddWithType,
    this.onAddItem,
    this.addItemTooltip = 'Add item',
    this.onAddItemWithType,
    this.parentSchemaNode,
    this.itemsSchemaNode,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    this.onInspect,
    this.visible = true,
    this.readOnly = false,
    this.theme = const YamlEditorTheme(),
  });

  @override
  Widget build(BuildContext context) {
    if (readOnly) return const SizedBox.shrink();

    var actions = <NodeAction>[];
    NodeAction? pinnedRemoveAction;

    // Add key button (schema suggestions and/or manual key entry fallback)
    if (theme.showAddButtons && (onAdd != null || onAddWithType != null)) {
      actions.add(NodeAction(
        icon: Icons.add,
        tooltip: 'Add key',
        color: theme.structureColors.addButton,
        onPressed: () => _showAddMenu(context),
      ));
    }

    // Add list-item button (direct or type-picker)
    if (theme.showAddButtons && (onAddItem != null || onAddItemWithType != null)) {
      actions.add(NodeAction(
        icon: Icons.playlist_add,
        tooltip: addItemTooltip,
        color: theme.structureColors.addButton,
        onPressed: onAddItemWithType != null
            ? () => _showAddItemTypeMenu(context)
            : onAddItem,
      ));
    }

    // Move-up button
    if (canMoveUp && onMoveUp != null) {
      actions.add(NodeAction(
        icon: Icons.arrow_upward,
        tooltip: 'Move up',
        color: theme.colors.hintColor,
        onPressed: onMoveUp,
      ));
    }

    // Move-down button
    if (canMoveDown && onMoveDown != null) {
      actions.add(NodeAction(
        icon: Icons.arrow_downward,
        tooltip: 'Move down',
        color: theme.colors.hintColor,
        onPressed: onMoveDown,
      ));
    }

    // Remove button
    if (theme.showRemoveButtons && canRemove && onRemove != null) {
      final removeAction = NodeAction(
        icon: Icons.close,
        tooltip: 'Remove',
        color: theme.structureColors.removeButton,
        onPressed: onRemove,
      );
      if (alwaysShowRemove) {
        pinnedRemoveAction = removeAction;
      } else {
        actions.add(removeAction);
      }
    }

    // Inspect button
    if (canInspect && onInspect != null) {
      actions.add(NodeAction(
        icon: Icons.code,
        tooltip: 'Edit as YAML',
        color: theme.colors.hintColor,
        onPressed: onInspect,
      ));
    }

    if (actions.isEmpty && pinnedRemoveAction == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.isNotEmpty)
          NodeActionRow(
            visible: visible,
            actions: actions,
          ),
        if (pinnedRemoveAction != null && actions.isNotEmpty)
          const SizedBox(width: 2),
        if (pinnedRemoveAction != null)
          ActionButton(
            icon: pinnedRemoveAction.icon,
            tooltip: pinnedRemoveAction.tooltip,
            onPressed: pinnedRemoveAction.onPressed,
            size: pinnedRemoveAction.size,
            color: pinnedRemoveAction.color,
          ),
      ],
    );
  }

  // Always open the full add-key dialog (which shows schema-suggested keys as
  // chips alongside the free-text key field). The intermediate showMenu picker
  // has been removed — the dialog itself handles schema suggestions.
  Future<void> _showAddMenu(BuildContext context) async {
    _showManualAddDialog(context);
  }

  void _showAddItemTypeMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    showMenu<AddKeyType>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: AddKeyType.values
          .map((t) => PopupMenuItem<AddKeyType>(
                value: t,
                height: 32,
                child: Text(t.label, style: const TextStyle(fontSize: 12)),
              ))
          .toList(),
    ).then((selected) {
      if (selected != null) onAddItemWithType?.call(selected.toValue());
    });
  }

  Future<void> _showManualAddDialog(BuildContext context) async {
    final result = await showAddKeyDialog(context, parentSchema: parentSchemaNode);
    if (result == null) return;
    if (onAddWithType != null) {
      onAddWithType!(result.key, result.value);
    } else {
      onAdd?.call(result.key);
    }
  }
}
