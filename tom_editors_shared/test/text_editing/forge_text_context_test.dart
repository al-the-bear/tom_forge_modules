import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('TextEditingContextImpl', () {
    test('creates with required fields', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [const TextSelection.collapsed(offset: 5)],
      );

      expect(context.text, 'Hello');
      expect(context.selections.length, 1);
      expect(context.cursorOffset, 5);
    });

    test('returns correct text length', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello World',
        selections: [],
      );

      expect(context.textLength, 11);
    });

    test('returns correct line count for single line', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [],
      );

      expect(context.lineCount, 1);
    });

    test('returns correct line count for multiple lines', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Line 1\nLine 2\nLine 3',
        selections: [],
      );

      expect(context.lineCount, 3);
    });

    test('hasSelection returns false for collapsed selection', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [const TextSelection.collapsed(offset: 2)],
      );

      expect(context.hasSelection, false);
    });

    test('hasSelection returns true for range selection', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [const TextSelection(baseOffset: 0, extentOffset: 5)],
      );

      expect(context.hasSelection, true);
    });

    test('cursorOffset from primary selection', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello World',
        selections: [const TextSelection.collapsed(offset: 6)],
      );

      expect(context.cursorOffset, 6);
    });

    test('cursorOffset null when no selections', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [],
      );

      expect(context.cursorOffset, isNull);
    });

    test('currentLine calculates correctly for first line', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello\nWorld',
        selections: [const TextSelection.collapsed(offset: 3)],
      );

      expect(context.currentLine, 0);
    });

    test('currentLine calculates correctly for second line', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello\nWorld',
        selections: [const TextSelection.collapsed(offset: 8)],
      );

      expect(context.currentLine, 1);
    });

    test('currentColumn calculates correctly at start of line', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello\nWorld',
        selections: [const TextSelection.collapsed(offset: 6)],
      );

      expect(context.currentColumn, 0);
    });

    test('currentColumn calculates correctly mid-line', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello\nWorld',
        selections: [const TextSelection.collapsed(offset: 9)],
      );

      expect(context.currentColumn, 3);
    });

    test('currentLineText returns correct line', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello\nWorld\nFoo',
        selections: [const TextSelection.collapsed(offset: 8)],
      );

      expect(context.currentLineText, 'World');
    });

    test('selectedText returns empty for collapsed selection', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [const TextSelection.collapsed(offset: 2)],
      );

      expect(context.selectedText, '');
    });

    test('selectedText returns selected range', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello World',
        selections: [const TextSelection(baseOffset: 0, extentOffset: 5)],
      );

      expect(context.selectedText, 'Hello');
    });

    test('isDirty defaults to false', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [],
      );

      expect(context.isDirty, false);
    });

    test('isDirty can be set to true', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [],
        isDirty: true,
      );

      expect(context.isDirty, true);
    });

    test('canUndo and canRedo default to false', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [],
      );

      expect(context.canUndo, false);
      expect(context.canRedo, false);
    });

    test('canUndo and canRedo can be set', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [],
        canUndo: true,
        canRedo: true,
      );

      expect(context.canUndo, true);
      expect(context.canRedo, true);
    });

    test('toString includes key info', () {
      final context = TextEditingContextImpl.withValues(
        text: 'Hello',
        selections: [const TextSelection.collapsed(offset: 5)],
      );

      final str = context.toString();
      expect(str, contains('5'));
      expect(str, contains('1')); // 1 selection
    });
  });
}
