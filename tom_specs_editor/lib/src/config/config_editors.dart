import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'config_field.dart';
import 'raw_file_module.dart';

/// Declarative description of a **list** config editor
/// (`tom_specs_editor_specification.md` §12): a backing store, the detail-form
/// fields, and the add/remove/label hooks. One generic [ConfigListEditor]
/// renders any of these, so the seven config editors share one
/// list-management/validation/raw-file implementation.
class ConfigListSpec<T> {
  ConfigListSpec({
    required this.title,
    required this.icon,
    required this.uri,
    required this.backingFile,
    required this.load,
    required this.save,
    required this.labelOf,
    required this.createNew,
    required this.fields,
    this.isReadOnly,
  });

  final String title;
  final IconData icon;
  final Uri uri;

  /// The YAML/markdown file the "Open raw file" button opens.
  final File backingFile;

  final List<T> Function() load;
  final void Function(List<T> items) save;

  /// Row label in the list pane.
  final String Function(T item) labelOf;

  /// Produces a fresh item for the "Add" button.
  final T Function() createNew;

  /// Detail-form fields rendered for the selected item.
  final List<ConfigField<T>> fields;

  /// When provided and true, the item is read-only (e.g. built-in chat
  /// variables): it cannot be removed and its fields render disabled.
  final bool Function(T item)? isReadOnly;
}

/// Declarative description of a **singleton** config editor
/// (`tom_specs_editor_specification.md` §12) — one object, no list. Used by the
/// Agent Settings editor.
class ConfigObjectSpec<T> {
  ConfigObjectSpec({
    required this.title,
    required this.icon,
    required this.uri,
    required this.backingFile,
    required this.load,
    required this.save,
    required this.fields,
  });

  final String title;
  final IconData icon;
  final Uri uri;
  final File backingFile;
  final T Function() load;
  final void Function(T value) save;
  final List<ConfigField<T>> fields;
}

/// A toolbar button that persists the current state then opens the backing file
/// via the injected [RawFileOpener] (`tom_specs_editor_specification.md` §12 —
/// "Open raw file").
class RawFileButton extends StatelessWidget {
  const RawFileButton({super.key, required this.uri, required this.onOpen});

  final Uri uri;
  final RawFileOpener onOpen;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('config-open-raw-file'),
      icon: const Icon(Icons.description_outlined, size: 18),
      label: const Text('Open raw file'),
      onPressed: () => onOpen(uri),
    );
  }
}

/// Generic list+detail config editor (`tom_specs_editor_specification.md` §12).
/// Handles selection, add/remove, per-field validation, persistence on edit,
/// and the raw-file button.
class ConfigListEditor<T> extends ForgeEditor {
  ConfigListEditor({required this.spec, required this.onOpenRawFile})
      : _title = ValueNotifier<String>(spec.title),
        _items = spec.load();

  final ConfigListSpec<T> spec;
  final RawFileOpener onOpenRawFile;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _isDirty = ValueNotifier<bool>(false);

  List<T> _items;

  @override
  IconData get icon => spec.icon;

  @override
  Uri get uri => spec.uri;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  void markClean() => _isDirty.value = false;

  // These editors are opened by the config rail, not by file resolution.
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  /// Ensures the backing file exists (persisting current state) then opens it.
  void _openRaw() {
    spec.save(_items);
    onOpenRawFile(Uri.file(spec.backingFile.path));
  }

  @override
  Widget buildMain(BuildContext context) => _ConfigListBody<T>(
        spec: spec,
        initialItems: _items,
        onItemsChanged: (items) {
          _items = items;
          spec.save(items);
          _isDirty.value = false;
        },
        onOpenRaw: _openRaw,
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _ConfigListBody<T> extends StatefulWidget {
  const _ConfigListBody({
    required this.spec,
    required this.initialItems,
    required this.onItemsChanged,
    required this.onOpenRaw,
  });

  final ConfigListSpec<T> spec;
  final List<T> initialItems;
  final ValueChanged<List<T>> onItemsChanged;
  final VoidCallback onOpenRaw;

  @override
  State<_ConfigListBody<T>> createState() => _ConfigListBodyState<T>();
}

class _ConfigListBodyState<T> extends State<_ConfigListBody<T>> {
  late List<T> _items = List<T>.of(widget.initialItems);
  int? _selected;

  ConfigListSpec<T> get spec => widget.spec;

  bool _isReadOnly(T item) => spec.isReadOnly?.call(item) ?? false;

  void _commit() => widget.onItemsChanged(List<T>.unmodifiable(_items));

  void _add() {
    setState(() {
      _items = [..._items, spec.createNew()];
      _selected = _items.length - 1;
    });
    _commit();
  }

  void _remove(int index) {
    setState(() {
      _items = [..._items]..removeAt(index);
      if (_selected != null && _selected! >= _items.length) {
        _selected = _items.isEmpty ? null : _items.length - 1;
      }
    });
    _commit();
  }

  void _replace(int index, T value) {
    setState(() {
      _items = [..._items];
      _items[index] = value;
    });
    _commit();
  }

  /// First field-level validation error for [item], or null when valid.
  String? _validate(T item) {
    for (final field in spec.fields) {
      final error = field.validate?.call(item);
      if (error != null) return error;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(context),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 220, child: _listPane(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _detailPane(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(spec.icon, size: 18),
          const SizedBox(width: 8),
          Text(spec.title, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          RawFileButton(
            uri: spec.uri,
            onOpen: (_) => widget.onOpenRaw(),
          ),
        ],
      ),
    );
  }

  Widget _listPane(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No entries'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final error = _validate(item);
                    return ListTile(
                      key: ValueKey('config-item-$index'),
                      dense: true,
                      selected: _selected == index,
                      leading: _isReadOnly(item)
                          ? const Icon(Icons.lock_outline, size: 16)
                          : null,
                      title: Text(
                        spec.labelOf(item),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: error != null
                          ? Tooltip(
                              message: error,
                              child: Icon(
                                Icons.error_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            )
                          : null,
                      onTap: () => setState(() => _selected = index),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Row(
          children: [
            IconButton(
              key: const Key('config-add'),
              tooltip: 'Add',
              icon: const Icon(Icons.add),
              onPressed: _add,
            ),
            IconButton(
              key: const Key('config-remove'),
              tooltip: 'Remove',
              icon: const Icon(Icons.remove),
              onPressed: (_selected != null && !_isReadOnly(_items[_selected!]))
                  ? () => _remove(_selected!)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailPane(BuildContext context) {
    final index = _selected;
    if (index == null || index >= _items.length) {
      return const Center(child: Text('Select an entry to edit'));
    }
    final item = _items[index];
    final readOnly = _isReadOnly(item);
    final error = _validate(item);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error,
              key: const Key('config-validation-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        AbsorbPointer(
          absorbing: readOnly,
          child: Opacity(
            opacity: readOnly ? 0.6 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in spec.fields)
                  field.buildField(item, (value) => _replace(index, value)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Generic singleton config editor (`tom_specs_editor_specification.md` §12) —
/// one object, validation, raw-file button. Used by the Agent Settings editor.
class ConfigObjectEditor<T> extends ForgeEditor {
  ConfigObjectEditor({required this.spec, required this.onOpenRawFile})
      : _title = ValueNotifier<String>(spec.title),
        _value = spec.load();

  final ConfigObjectSpec<T> spec;
  final RawFileOpener onOpenRawFile;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _isDirty = ValueNotifier<bool>(false);

  T _value;

  @override
  IconData get icon => spec.icon;

  @override
  Uri get uri => spec.uri;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  void markClean() => _isDirty.value = false;

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  void _openRaw() {
    spec.save(_value);
    onOpenRawFile(Uri.file(spec.backingFile.path));
  }

  @override
  Widget buildMain(BuildContext context) => _ConfigObjectBody<T>(
        spec: spec,
        initialValue: _value,
        onValueChanged: (value) {
          _value = value;
          spec.save(value);
        },
        onOpenRaw: _openRaw,
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _ConfigObjectBody<T> extends StatefulWidget {
  const _ConfigObjectBody({
    required this.spec,
    required this.initialValue,
    required this.onValueChanged,
    required this.onOpenRaw,
  });

  final ConfigObjectSpec<T> spec;
  final T initialValue;
  final ValueChanged<T> onValueChanged;
  final VoidCallback onOpenRaw;

  @override
  State<_ConfigObjectBody<T>> createState() => _ConfigObjectBodyState<T>();
}

class _ConfigObjectBodyState<T> extends State<_ConfigObjectBody<T>> {
  late T _value = widget.initialValue;

  ConfigObjectSpec<T> get spec => widget.spec;

  String? _validate() {
    for (final field in spec.fields) {
      final error = field.validate?.call(_value);
      if (error != null) return error;
    }
    return null;
  }

  void _replace(T value) {
    setState(() => _value = value);
    widget.onValueChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final error = _validate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(spec.icon, size: 18),
              const SizedBox(width: 8),
              Text(spec.title, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              RawFileButton(
                uri: spec.uri,
                onOpen: (_) => widget.onOpenRaw(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    error,
                    key: const Key('config-validation-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              for (final field in spec.fields)
                field.buildField(_value, _replace),
            ],
          ),
        ),
      ],
    );
  }
}
