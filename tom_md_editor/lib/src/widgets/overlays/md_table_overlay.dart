import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../debug/md_editor_debug.dart';
import '../../theme/md_editor_theme.dart';

/// Column alignment for markdown tables.
enum ColumnAlignment { left, center, right }

/// Overlay dialog for editing markdown tables with a spreadsheet-like UI.
///
/// Features:
/// - Arrow key navigation between cells
/// - Enter moves down; in the last row it appends a new row first
/// - Insert row above/below and column left/right relative to focused cell
/// - Drag handles for reordering rows and columns
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
  late List<FocusNode> _focusNodes;
  late List<ColumnAlignment> _alignments;
  int _focusedRow = 0;
  int _focusedCol = 0;

  /// Index of the row currently being dragged, or -1.
  int _draggingRow = -1;
  /// Index of the column currently being dragged, or -1.
  int _draggingCol = -1;
  /// Index of the row that is the current drop target, or -1.
  int _dropTargetRow = -1;
  /// Index of the column that is the current drop target, or -1.
  int _dropTargetCol = -1;

  static const double _handleWidth = 28.0;

  int get _rows => _cells.length;
  int get _cols => _cells.isEmpty ? 0 : _cells.first.length;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<TextEditingController> _buildControllers() {
    return _cells
        .expand((row) => row)
        .map((cell) => TextEditingController(text: cell))
        .toList();
  }

  List<FocusNode> _buildFocusNodes() {
    return List.generate(_rows * _cols, (_) => FocusNode());
  }

  TextEditingController _controllerAt(int r, int c) =>
      _controllers[r * _cols + c];

  FocusNode _focusNodeAt(int r, int c) => _focusNodes[r * _cols + c];

  void _focusCell(int row, int col, {int? cursorPosition}) {
    if (row < 0 || row >= _rows || col < 0 || col >= _cols) return;
    _focusNodeAt(row, col).requestFocus();
    if (cursorPosition != null) {
      final ctrl = _controllerAt(row, col);
      ctrl.selection = TextSelection.collapsed(
        offset: cursorPosition.clamp(0, ctrl.text.length),
      );
    }
  }

  void _syncCells() {
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        _cells[r][c] = _controllerAt(r, c).text;
      }
    }
  }

  void _disposeAll() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
  }

  /// Perform a structural mutation (insert/remove/reorder rows or columns).
  ///
  /// Syncs cell text from controllers, disposes old controllers and focus nodes,
  /// runs [mutation], rebuilds both, and optionally focuses a cell after rebuild.
  void _mutate(
    void Function() mutation, {
    int? focusRow,
    int? focusCol,
  }) {
    _syncCells();
    _disposeAll();
    mutation();
    _controllers = _buildControllers();
    _focusNodes = _buildFocusNodes();
    final fr = (focusRow ?? _focusedRow).clamp(0, _rows - 1);
    final fc = (focusCol ?? _focusedCol).clamp(0, _cols - 1);
    setState(() {
      _focusedRow = fr;
      _focusedCol = fc;
    });
    if (focusRow != null || focusCol != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusCell(fr, fc, cursorPosition: 0);
      });
    }
  }

  TextAlign _textAlignFor(int col) {
    if (col >= _alignments.length) return TextAlign.start;
    return switch (_alignments[col]) {
      ColumnAlignment.left => TextAlign.start,
      ColumnAlignment.center => TextAlign.center,
      ColumnAlignment.right => TextAlign.end,
    };
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  List<List<String>> _parseTable(String table) {
    try {
      final lines =
          table.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) {
        return [
          <String>['Header'],
          <String>['Cell'],
        ];
      }
      final result = <List<String>>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (RegExp(r'^[\|\s\-:]+$').hasMatch(trimmed)) continue;
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList(); // growable
        if (cells.isNotEmpty) result.add(cells);
      }
      if (result.isNotEmpty) {
        final maxCols =
            result.fold<int>(0, (m, r) => r.length > m ? r.length : m);
        for (final row in result) {
          while (row.length < maxCols) {
            row.add('');
          }
        }
      }
      return result.isEmpty
          ? [
              <String>['Header'],
              <String>['Cell'],
            ]
          : result;
    } catch (e, st) {
      MdEditorDebug.logger.error('Error parsing table', e, st);
      return [
        <String>['Header'],
        <String>['Cell'],
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
          final hasLeft = p.startsWith(':');
          final hasRight = p.endsWith(':');
          if (hasLeft && hasRight) return ColumnAlignment.center;
          if (hasRight) return ColumnAlignment.right;
          return ColumnAlignment.left;
        }).toList();
      }
    }
    return List.generate(_cols, (_) => ColumnAlignment.left);
  }

  // ---------------------------------------------------------------------------
  // Key events
  // ---------------------------------------------------------------------------

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
        _addRowAtEnd();
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

  // ---------------------------------------------------------------------------
  // Row / Column mutations
  // ---------------------------------------------------------------------------

  /// Append a row at the end (used by Enter key in last row).
  void _addRowAtEnd() {
    _syncCells();
    _disposeAll();
    _cells.add(List<String>.filled(_cols, '', growable: true));
    _controllers = _buildControllers();
    _focusNodes = _buildFocusNodes();
    setState(() {});
  }

  void _insertRowAbove() {
    final target = _focusedRow;
    if (target == 0) return;
    _mutate(
      () => _cells.insert(
        target,
        List<String>.filled(_cols, '', growable: true),
      ),
      focusRow: target,
      focusCol: _focusedCol,
    );
  }

  void _insertRowBelow() {
    final target = _focusedRow + 1;
    _mutate(
      () => _cells.insert(
        target,
        List<String>.filled(_cols, '', growable: true),
      ),
      focusRow: target,
      focusCol: _focusedCol,
    );
  }

  void _insertColumnLeft() {
    final target = _focusedCol;
    _mutate(() {
      for (final row in _cells) {
        row.insert(target, '');
      }
      _alignments.insert(target, ColumnAlignment.left);
    }, focusRow: 0, focusCol: target);
  }

  void _insertColumnRight() {
    final target = _focusedCol + 1;
    _mutate(() {
      for (final row in _cells) {
        row.insert(target, '');
      }
      _alignments.insert(target, ColumnAlignment.left);
    }, focusRow: 0, focusCol: target);
  }

  void _removeRow() {
    if (_rows <= 2 || _focusedRow == 0) return;
    _mutate(() => _cells.removeAt(_focusedRow));
  }

  void _removeColumn() {
    if (_cols <= 1) return;
    final target = _focusedCol.clamp(0, _cols - 1);
    _mutate(() {
      for (final row in _cells) {
        if (target < row.length) row.removeAt(target);
      }
      if (target < _alignments.length) _alignments.removeAt(target);
    });
  }

  void _reorderRows(int from, int to) {
    if (from == to || from == 0 || to == 0) return;
    _mutate(() {
      final row = _cells.removeAt(from);
      _cells.insert(to, row);
    }, focusRow: to, focusCol: _focusedCol);
  }

  void _reorderColumns(int from, int to) {
    if (from == to) return;
    _mutate(() {
      for (final row in _cells) {
        final cell = row.removeAt(from);
        row.insert(to, cell);
      }
      final align = _alignments.removeAt(from);
      _alignments.insert(to, align);
    }, focusRow: _focusedRow, focusCol: to);
  }

  // ---------------------------------------------------------------------------
  // Save / Markdown
  // ---------------------------------------------------------------------------

  void _save() {
    try {
      _syncCells();
      widget.onSave(_toMarkdown());
      Navigator.of(context).pop();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error saving table', e, st);
    }
  }

  String _toMarkdown() {
    if (_cells.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('| ${_cells.first.join(' | ')} |');
    final seps = List.generate(_cols, (c) {
      final a =
          c < _alignments.length ? _alignments[c] : ColumnAlignment.left;
      return switch (a) {
        ColumnAlignment.left => '---',
        ColumnAlignment.center => ':---:',
        ColumnAlignment.right => '---:',
      };
    });
    buf.writeln('| ${seps.join(' | ')} |');
    for (var r = 1; r < _rows; r++) {
      buf.writeln('| ${_cells[r].join(' | ')} |');
    }
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;

    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
        decoration: BoxDecoration(
          color: basic.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: basic.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDialogHeader(basic),
            _buildColumnHandles(basic),
            Expanded(child: _buildTableBody(basic)),
            _buildActions(basic),
            _buildFooter(basic),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(MdBasicTheme basic) {
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
            'Edit Table ($_rows rows \u00d7 $_cols columns)',
            style: TextStyle(color: basic.text, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Row of draggable column handles above the table for reordering columns.
  Widget _buildColumnHandles(MdBasicTheme basic) {
    return Padding(
      padding: EdgeInsets.only(left: 12.0 + _handleWidth, right: 12.0),
      child: Row(
        children: List.generate(_cols, (c) {
          final isDragged = _draggingCol == c;
          final isTarget = _dropTargetCol == c && _draggingCol != -1;
          return Expanded(
            child: DragTarget<int>(
              onWillAcceptWithDetails: (d) {
                setState(() => _dropTargetCol = c);
                return true;
              },
              onLeave: (_) {
                if (_dropTargetCol == c) {
                  setState(() => _dropTargetCol = -1);
                }
              },
              onAcceptWithDetails: (d) {
                setState(() => _dropTargetCol = -1);
                _reorderColumns(d.data, c);
              },
              builder: (ctx, candidates, _) {
                return Draggable<int>(
                  data: c,
                  axis: Axis.horizontal,
                  onDragStarted: () => setState(() => _draggingCol = c),
                  onDragEnd: (_) => setState(() {
                    _draggingCol = -1;
                    _dropTargetCol = -1;
                  }),
                  onDraggableCanceled: (velocity, offset) => setState(() {
                    _draggingCol = -1;
                    _dropTargetCol = -1;
                  }),
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: basic.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.drag_handle, size: 14,
                          color: basic.accent),
                    ),
                  ),
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: isDragged
                          ? basic.textMuted.withValues(alpha: 0.15)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: basic.border, width: 0.5),
                        left: isTarget
                            ? BorderSide(color: basic.accent, width: 2)
                            : BorderSide.none,
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.drag_handle, size: 12,
                          color: isDragged
                              ? basic.textMuted.withValues(alpha: 0.3)
                              : basic.textMuted),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTableBody(MdBasicTheme basic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: List.generate(_rows, (r) => _buildRow(basic, r)),
      ),
    );
  }

  Widget _buildRow(MdBasicTheme basic, int r) {
    final isHeader = r == 0;
    final isRowDragged = _draggingRow == r;
    final isRowTarget = _dropTargetRow == r && _draggingRow != -1;

    final Widget handle;
    if (isHeader) {
      handle = const SizedBox(width: _handleWidth);
    } else {
      handle = DragTarget<int>(
        onWillAcceptWithDetails: (d) {
          setState(() => _dropTargetRow = r);
          return true;
        },
        onLeave: (_) {
          if (_dropTargetRow == r) {
            setState(() => _dropTargetRow = -1);
          }
        },
        onAcceptWithDetails: (d) {
          setState(() => _dropTargetRow = -1);
          _reorderRows(d.data, r);
        },
        builder: (ctx, candidates, _) {
          return Draggable<int>(
            data: r,
            axis: Axis.vertical,
            onDragStarted: () => setState(() => _draggingRow = r),
            onDragEnd: (_) => setState(() {
              _draggingRow = -1;
              _dropTargetRow = -1;
            }),
            onDraggableCanceled: (velocity, offset) => setState(() {
              _draggingRow = -1;
              _dropTargetRow = -1;
            }),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: _handleWidth,
                height: 28,
                decoration: BoxDecoration(
                  color: basic.accent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.drag_indicator, size: 14,
                    color: basic.accent),
              ),
            ),
            child: SizedBox(
              width: _handleWidth,
              height: 28,
              child: Center(
                child: Icon(
                  Icons.drag_indicator,
                  size: 14,
                  color: isRowDragged
                      ? basic.textMuted.withValues(alpha: 0.3)
                      : basic.textMuted,
                ),
              ),
            ),
          );
        },
      );
    }

    final rowContent = Row(
      children: [
        handle,
        ...List.generate(_cols, (c) {
          final isFocused = _focusedRow == r && _focusedCol == c;
          final isColDragged = _draggingCol == c;
          final isColTarget = _dropTargetCol == c && _draggingCol != -1;
          final isDimmed = isRowDragged || isColDragged;
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDimmed
                    ? basic.textMuted.withValues(alpha: 0.08)
                    : isHeader
                        ? basic.surfaceVariant
                        : Colors.transparent,
                border: Border(
                  top: isRowTarget
                      ? BorderSide(color: basic.accent, width: 2)
                      : BorderSide(color: basic.border, width: 0.5),
                  bottom: BorderSide(
                    color: isFocused ? basic.accent : basic.border,
                    width: isFocused ? 1.0 : 0.5,
                  ),
                  left: isColTarget
                      ? BorderSide(color: basic.accent, width: 2)
                      : BorderSide(
                          color: isFocused ? basic.accent : basic.border,
                          width: isFocused ? 1.0 : 0.5,
                        ),
                  right: BorderSide(
                    color: isFocused ? basic.accent : basic.border,
                    width: isFocused ? 1.0 : 0.5,
                  ),
                ),
              ),
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
                child: Opacity(
                  opacity: isDimmed ? 0.35 : 1.0,
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
              ),
            ),
          );
        }),
      ],
    );

    return rowContent;
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
                onPressed: _focusedRow > 0 ? _insertRowAbove : null,
                icon: const Icon(Icons.arrow_upward, size: 14),
                label: const Text('Row Above'),
              ),
              TextButton.icon(
                onPressed: _insertRowBelow,
                icon: const Icon(Icons.arrow_downward, size: 14),
                label: const Text('Row Below'),
              ),
              TextButton.icon(
                onPressed: _insertColumnLeft,
                icon: const Icon(Icons.arrow_back, size: 14),
                label: const Text('Col Left'),
              ),
              TextButton.icon(
                onPressed: _insertColumnRight,
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('Col Right'),
              ),
              if (_focusedRow > 0 && _rows > 2)
                TextButton.icon(
                  onPressed: _removeRow,
                  icon: const Icon(Icons.remove, size: 14),
                  label: Text('Remove Row ${_focusedRow + 1}'),
                ),
              if (_cols > 1)
                TextButton.icon(
                  onPressed: _removeColumn,
                  icon: const Icon(Icons.remove, size: 14),
                  label: Text('Remove Col ${_focusedCol + 1}'),
                ),
            ],
          ),
          const SizedBox(height: 4),
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
}
