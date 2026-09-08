import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../structure/spec_model.dart';
import 'markdown_document.dart';
import 'root_navigator.dart';
import 'spec_document_controller.dart';

/// The markdown import/export dialogs (`tom_specs_editor_specification.md`
/// §15.2).
///
/// Export offers a **scope** — *single* (one root projection), *multiple* (a
/// subset of roots), or *global* (the Solution Blueprint master) — previews the
/// generated, schema-conformant markdown, and can **save it to a `*.md` file**.
/// Import either pastes markdown or **loads it from a `*.md` file**, then
/// applies it as a full overwrite of the covered scope, surfacing the
/// parse-rejection report so nothing is silently dropped (OE-19 per-file IO).
///
/// The actual file open/save call is behind the [MarkdownFileIo] seam so the
/// dialogs are testable without the platform file-picker channel; the default
/// [FilePickerMarkdownFileIo] uses `file_picker` + `dart:io`.

/// The file open/save seam the markdown dialogs use, so a test can supply a fake
/// instead of driving the real platform file-picker channel.
abstract class MarkdownFileIo {
  /// Prompts for a save location (suggesting [suggestedName]), writes [content]
  /// there, and returns the written path — or `null` if the user cancelled.
  Future<String?> saveText(String suggestedName, String content);

  /// Prompts for a `*.md` file to open and returns its text — or `null` if the
  /// user cancelled.
  Future<String?> openText();
}

/// The default [MarkdownFileIo], backed by `file_picker` + `dart:io`.
class FilePickerMarkdownFileIo implements MarkdownFileIo {
  const FilePickerMarkdownFileIo();

  @override
  Future<String?> saveText(String suggestedName, String content) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export markdown',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (path == null) return null;
    final file = File(path);
    await file.writeAsString(content);
    return file.path;
  }

  @override
  Future<String?> openText() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import markdown',
      type: FileType.custom,
      allowedExtensions: const ['md'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (picked.bytes != null) return utf8.decode(picked.bytes!);
    final path = picked.path;
    return path == null ? null : File(path).readAsString();
  }
}

/// Opens the export dialog for [controller]'s roots.
Future<void> showMarkdownExportDialog(
  BuildContext context,
  SpecDocumentController controller, {
  MarkdownFileIo fileIo = const FilePickerMarkdownFileIo(),
}) async {
  final roots = controller.model.roots;
  if (roots.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (_) => MarkdownExportDialog(
      controller: controller,
      roots: roots,
      fileIo: fileIo,
    ),
  );
}

/// Opens the import dialog for [controller].
Future<void> showMarkdownImportDialog(
  BuildContext context,
  SpecDocumentController controller, {
  MarkdownFileIo fileIo = const FilePickerMarkdownFileIo(),
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        MarkdownImportDialog(controller: controller, fileIo: fileIo),
  );
}

/// Scope + root selection with a live markdown preview.
class MarkdownExportDialog extends StatefulWidget {
  const MarkdownExportDialog({
    super.key,
    required this.controller,
    required this.roots,
    this.fileIo = const FilePickerMarkdownFileIo(),
  });

  final SpecDocumentController controller;
  final List<SpecRoot> roots;
  final MarkdownFileIo fileIo;

  @override
  State<MarkdownExportDialog> createState() => _MarkdownExportDialogState();
}

class _MarkdownExportDialogState extends State<MarkdownExportDialog> {
  MarkdownScope _scope = MarkdownScope.global;
  late final List<SpecRoot> _ordered = navigatorRootOrder(
    widget.controller.model,
  );
  late final SpecRoot _pdRoot = defaultNavigatorRoot(widget.controller.model)!;
  late SpecRoot _single = _pdRoot;
  final Set<String> _multiple = {};

  /// The path of the most recent successful save, surfaced inline.
  String? _savedPath;
  bool _saving = false;

  String _seg(SpecRoot r) => r.sectionId ?? r.type;

  List<SpecRoot> get _selectedRoots {
    switch (_scope) {
      case MarkdownScope.global:
        return [_pdRoot];
      case MarkdownScope.single:
        return [_single];
      case MarkdownScope.multiple:
        return _ordered.where((r) => _multiple.contains(_seg(r))).toList();
    }
  }

  String get _preview {
    final roots = _selectedRoots;
    if (roots.isEmpty) return '(select at least one root)';
    return roots
        .map((r) => widget.controller.exportMarkdown(_seg(r)))
        .join('\n\n<!-- ─────────────── next document ─────────────── -->\n\n');
  }

  /// Suggests a file name from the selected scope: the single root's segment for
  /// one root, otherwise a generic name for a multi-root bundle.
  String get _suggestedName {
    final roots = _selectedRoots;
    return roots.length == 1 ? '${_seg(roots.single)}.md' : 'spec_export.md';
  }

  Future<void> _saveToFile() async {
    if (_selectedRoots.isEmpty || _saving) return;
    setState(() => _saving = true);
    String? path;
    try {
      path = await widget.fileIo.saveText(_suggestedName, _preview);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          if (path != null) _savedPath = path;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export markdown'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<MarkdownScope>(
              segments: const [
                ButtonSegment(
                  value: MarkdownScope.global,
                  label: Text('Global'),
                ),
                ButtonSegment(
                  value: MarkdownScope.single,
                  label: Text('Single'),
                ),
                ButtonSegment(
                  value: MarkdownScope.multiple,
                  label: Text('Multiple'),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
            ),
            const SizedBox(height: 8),
            if (_scope == MarkdownScope.single)
              DropdownButton<String>(
                value: _seg(_single),
                isExpanded: true,
                items: [
                  for (final r in _ordered)
                    DropdownMenuItem(value: _seg(r), child: Text(r.title)),
                ],
                onChanged: (v) => setState(
                  () => _single = _ordered.firstWhere((r) => _seg(r) == v),
                ),
              ),
            if (_scope == MarkdownScope.multiple)
              SizedBox(
                height: 140,
                child: ListView(
                  children: [
                    for (final r in _ordered)
                      CheckboxListTile(
                        dense: true,
                        title: Text(r.title),
                        value: _multiple.contains(_seg(r)),
                        onChanged: (on) => setState(() {
                          if (on ?? false) {
                            _multiple.add(_seg(r));
                          } else {
                            _multiple.remove(_seg(r));
                          }
                        }),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Preview',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _preview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            if (_savedPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Saved to $_savedPath',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _selectedRoots.isEmpty || _saving ? null : _saveToFile,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save to file…'),
        ),
      ],
    );
  }
}

/// Pasted-markdown import with a rejection report.
class MarkdownImportDialog extends StatefulWidget {
  const MarkdownImportDialog({
    super.key,
    required this.controller,
    this.fileIo = const FilePickerMarkdownFileIo(),
  });

  final SpecDocumentController controller;
  final MarkdownFileIo fileIo;

  @override
  State<MarkdownImportDialog> createState() => _MarkdownImportDialogState();
}

class _MarkdownImportDialogState extends State<MarkdownImportDialog> {
  final TextEditingController _input = TextEditingController();
  MarkdownImportResult? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _import() {
    setState(() => _result = widget.controller.importMarkdown(_input.text));
  }

  /// Loads a `*.md` file into the input field for review before importing. The
  /// user still presses **Import** so the overwrite + rejection report stay an
  /// explicit step.
  Future<void> _loadFromFile() async {
    final text = await widget.fileIo.openText();
    if (text == null || !mounted) return;
    setState(() {
      _input.text = text;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AlertDialog(
      title: const Text('Import markdown'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import overwrites every section under the covered root(s). '
              'Unmapped or malformed blocks are listed below — not dropped.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _input,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste *.md content…',
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(
                result.isClean
                    ? 'Imported ${result.appliedCount} value(s) cleanly.'
                    : 'Imported ${result.appliedCount} value(s); '
                          '${result.rejections.length} rejected:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: result.isClean
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              for (final r in result.rejections)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '• $r',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton.icon(
          onPressed: _loadFromFile,
          icon: const Icon(Icons.folder_open_outlined, size: 16),
          label: const Text('Load from file…'),
        ),
        FilledButton(onPressed: _import, child: const Text('Import')),
      ],
    );
  }
}
