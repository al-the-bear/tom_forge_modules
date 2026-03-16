import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../debug/md_editor_debug.dart';
import '../../theme/md_editor_theme.dart';

/// Column alignment for markdown tables.
enum ColumnAlignment { left, center, right }

/// Overlay dialog for editing markdown tables with a spreadsheet-like UI.
class MdTableOverlay extends StatefulWidget {
  const MdTableOverlay({
    super.key,
    required this.markdownTable,
    required this.theme,
    required this.onSave,
    this.onCancel,
  });

  /// The original markdown table string.
  final String markdownTable;
  final MdEditorTheme theme;
  final ValueChanged<String> onSave;
  final VoidCallback? onCancel;

  @override
  State<MdTableOverlay> createState() => _MdTableOverlayState();
}

class _MdTableOverlayState extends State<MdTableOverlay> {
  late List<List<String>> _cells;
  late List<TextEditingController> _controllers;
  late List<ColumnAlignment> _alignments;
  int _focusedRow = 0;
  int _focusedCol = 0;

  int get _rows => _cells.length;
  int get _cols => _cells.isEmpty ? 0 : _cells.first.length;

  late List<FocusNode> _focusNodes;

  List<FocusNode> _buildFocusNodes() {
    return List.generate(_rows * _cols, (_) => FocusNode());
  }

  FocusNode _focusNodeAt(int row, int col) => _focusNodes[row * _cols + col];

  void _focusCell(int row, int col, {int? cursorPosition}) {
    if (row < 0 || row >= _rows || col < 0 || col >= _cols) return;
    _focusNodeAt(row, col).requestFocus();
    if (cursorPosition != null) {
      final ctrl = _controllerAt(row, col);
      final pos = cursorPosition.clamp(0, ctrl.text.length);
      ctrl.selection = TextSelection.collapsed(offset: pos);
    }
  }

  KeyEventResult _onCellKeyEvent(
    int row,
    int col,
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (row > 0) _focusCell(row - 1, col);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (row < _rows - 1) _focusCell(row + 1, col);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      final ctrl = _controllerAt(row, col);
      if (ctrl.selection.baseOffset == 0 &&
          ctrl.selection.extentOffset == 0 &&
          col > 0) {
        _focusCell(
          row,
          col - 1,
          cursorPosition: _controllerAt(row, col - 1).text.length,
        );
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final ctrl = _controllerAt(row, col);
      if (ctrl.selection.baseOffset == ctrl.text.length &&
          ctrl.selection.extentOffset == ctrl.text.length &&
          col < _cols - 1) {
        _focusCell(row, col + 1, cursorPosition: 0);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (row == _rows - 1) {
        _addRow();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusCell(row + 1, col, cursorPosition: 0);
        });
      } else {
        _focusCell(row + 1, col, cursorPosition: 0);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    _cells = _parseTable(widget.markdownTable);
    _alignments = _parseAlignments(widget.markdownTable);
    _controllers = _buildControllers();
    _focusNodes = _buildFocusNodes();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  List<List<String>> _parseTable(String table) {
    try {
      final lines =
          table
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .toList();
      if (lines.length < 2) {
        return [
          ['Header'],
          ['Cell'],
        ];
      }
      final result = <List<String>>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Skip separator line (---|---|...).
        if (RegExp(r'^[\|\s\-:]+$').hasMatch(line)) continue;
        final cells =
            line
                .split('|')
                .map((c) => c.trim())
                .where((c) => c.isNotEmpty)
                .toList();
        if (cells.isNotEmpty) result.add(cells);
      }
      // Normalize column count.
      if (result.isNotEmpty) {
        final maxCols = result.fold<int>(
          0,
          (m, row) => row.length > m ? row.length : m,
        );
        for (final row in result) {
          while (row.length < maxCols) {
            row.add('');
          }
        }
      }
      return result.isEmpty
          ? [
            ['Header'],
            ['Cell'],
          ]
          : result;
    } catch (e, st) {
      MdEditorDebug.logger.error('Error parsing table', e, st);
      return [
        ['Header'],
        ['Cell'],
      ];
    }
  }

  List<ColumnAlignment> _parseAlignments(String table) {
    final lines = table.split('\n').where((l) => l.trim().isNotEmpty).toList();
    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^[\|\s\-:]+$').hasMatch(trimmed)) {
        final parts = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        return parts.map((p) {
          final left = p.startsWith(':');
          final right = p.endsWith(':');
          if (left && right) return ColumnAlignment.center;
          if (right) return ColumnAlignment.right;
          return ColumnAlignment.left;
        }).toList();
      }
    }
    return List.filled(_cols, ColumnAlignment.left);
  }

  List<TextEditingController> _buildControllers() {
    return _cells
        .expand((row) => row)
        .map((cell) => TextEditingController(text: cell))
        .toList();
  }

  TextEditingController _controllerAt(int row, int col) {
    return _controllers[row * _cols + col];
  }

  TextAlign _textAlignFor(int col) {
    if (col >= _alignments.length) return TextAlign.start;
    return switch (_alignments[col]) {
      ColumnAlignment.left => TextAlign.start,
      ColumnAlignment.center => TextAlign.center,
      ColumnAlignment.right => TextAlign.end,
    };
  }

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;

    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 500),
        decoration: BoxDecoration(
          color: basic.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: basic.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(basic),
            Expanded(child: _buildTable(basic)),
            _buildActions(basic),
            _buildFooter(basic),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MdBasicTheme basic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: basic.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart, size: 18, color: basic.accent),
          const SizedBox(width: 8),
          Text(
            'Edit Table ($_rows rows × $_cols columns)',
            style: TextStyle(color: basic.text, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(MdBasicTheme basic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Table(
        border: TableBorder.all(color: basic.border),
        children: List.generate(_rows, (r) {
          final isHeader = r == 0;
          return TableRow(
            decoration: BoxDecoration(
              color: isHeader ? basic.surfaceVariant : Colors.transparent,
            ),
            children: List.generate(_cols, (c) {
              return Padding(
                padding: const EdgeInsets.all(2),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus) {
                      setState(() {
                        _focusedRow = r;
                        _focusedCol = c;
                      });
                    }
                  },
                  onKeyEvent: (node, event) =>
                      _onCellKeyEvent(r, c, node, event),
                  child: TextField(
                    focusNode: _focusNodeAt(r, c),
                    controller: _controllerAt(r, c),
                    textAlign: _textAlignFor(c),
                    style: TextStyle(
                      color: basic.text,
                      fontSize: 13,
                      fontWeight:
                          isHeader ? FontWeight.w600 : FontWeight.normal,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildActions(MdBasicTheme basic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Row'),
              ),
              TextButton.icon(
                onPressed: _addColumn,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Column'),
              ),
              if (_rows > 2)
                TextButton.icon(
                  onPressed: _removeRow,
                  icon: const Icon(Icons.remove, size: 14),
                  label: Text(
                    'Remove Row ${_focusedRow + 1}',
                  ),
                ),
              if (_cols > 1)
                TextButton.icon(
                  onPressed: _removeColumn,
                  icon: const Icon(Icons.remove, size: 14),
                  label: Text(
                    'Remove Col ${_focusedCol + 1}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Column alignment controls
          Row(
            children: [
              Text(
                'Alignment: ',
                style: TextStyle(color: basic.textMuted, fontSize: 12),
              ),
              ...List.generate(_cols, (c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _alignmentButton(basic, c),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alignmentButton(MdBasicTheme basic, int col) {
    final alignment = col < _alignments.length
        ? _alignments[col]
        : ColumnAlignment.left;
    final icon = switch (alignment) {
      ColumnAlignment.left => Icons.format_align_left,
      ColumnAlignment.center => Icons.format_align_center,
      ColumnAlignment.right => Icons.format_align_right,
    };
    return InkWell(
      onTap: () {
        setState(() {
          while (_alignments.length <= col) {
            _alignments.add(ColumnAlignment.left);
          }
          _alignments[col] = switch (_alignments[col]) {
            ColumnAlignment.left => ColumnAlignment.center,
            ColumnAlignment.center => ColumnAlignment.right,
            ColumnAlignment.right => ColumnAlignment.left,
          };
        });
      },
      child: Tooltip(
        message: 'Col ${col + 1}: ${alignment.name}',
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: basic.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14, color: basic.textMuted),
        ),
      ),
    );
  }

  Widget _buildFooter(MdBasicTheme basic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: basic.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }

  void _addRow() {
    setState(() {
      final newRow = List.filled(_cols, '');
      _cells.add(newRow);
      for (final cell in newRow) {
        _controllers.add(TextEditingController(text: cell));
      }
      for (var i = 0; i < _cols; i++) {
        _focusNodes.add(FocusNode());
      }
    });
  }

  void _addColumn() {
    setState(() {
      for (final c in _controllers) {
        c.dispose();
      }
      for (final n in _focusNodes) {
        n.dispose();
      }
      for (final row in _cells) {
        row.add('');
      }
      _alignments.add(ColumnAlignment.left);
      _controllers = _buildControllers();
      _focusNodes = _buildFocusNodes();
    });
    final targetCol = _cols - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCell(0, targetCol, cursorPosition: 0);
    });
  }

  void _removeRow() {
    if (_rows <= 2) return;
    // Don't allow removing the header row (row 0).
    final target = _focusedRow == 0 ? _rows - 1 : _focusedRow;
    setState(() {
      // Sync controller text back before removing.
      for (var c = 0; c < _cols; c++) {
        _cells[target][c] = _controllerAt(target, c).text;
      }
      _cells.removeAt(target);
      for (final c in _controllers) {
        c.dispose();
      }
      for (final n in _focusNodes) {
        n.dispose();
      }
      _controllers = _buildControllers();
      _focusNodes = _buildFocusNodes();
      _focusedRow = _focusedRow.clamp(0, _rows - 1);
    });
  }

  void _removeColumn() {
    if (_cols <= 1) return;
    final target = _focusedCol.clamp(0, _cols - 1);
    setState(() {
      for (final c in _controllers) {
        c.dispose();
      }
      for (final n in _focusNodes) {
        n.dispose();
      }
      for (final row in _cells) {
        if (target < row.length) row.removeAt(target);
      }
      if (target < _alignments.length) _alignments.removeAt(target);
      _controllers = _buildControllers();
      _focusNodes = _buildFocusNodes();
      _focusedCol = _focusedCol.clamp(0, _cols - 1);
    });
  }

  void _save() {
    try {
      // Read current values from controllers.
      for (var r = 0; r < _rows; r++) {
        for (var c = 0; c < _cols; c++) {
          _cells[r][c] = _controllerAt(r, c).text;
        }
      }
      final markdown = _toMarkdown();
      widget.onSave(markdown);
      Navigator.of(context).pop();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error saving table', e, st);
    }
  }

  String _toMarkdown() {
    if (_cells.isEmpty) return '';
    final buf = StringBuffer();
    // Header row.
    buf.writeln('| ${_cells.first.join(' | ')} |');
    // Separator row with alignment.
    final separators = List.generate(_cols, (c) {
      final align = c < _alignments.length
          ? _alignments[c]
          : ColumnAlignment.left;
      return switch (align) {
        ColumnAlignment.left => '---',
        ColumnAlignment.center => ':---:',
        ColumnAlignment.right => '---:',
      };
    });
    buf.writeln('| ${separators.join(' | ')} |');
    // Data rows.
    for (var r = 1; r < _rows; r++) {
      buf.writeln('| ${_cells[r].join(' | ')} |');
    }
    return buf.toString();
  }
}
