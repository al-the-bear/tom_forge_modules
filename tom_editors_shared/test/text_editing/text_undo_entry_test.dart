import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('TextUndoEntry', () {
    test('creates with required fields', () {
      final entry = TextUndoEntry(
        oldText: 'Hello',
        newText: 'Hello World',
      );

      expect(entry.oldText, 'Hello');
      expect(entry.newText, 'Hello World');
      expect(entry.oldSelection, isNull);
      expect(entry.newSelection, isNull);
      expect(entry.timestamp, isNotNull);
    });

    test('creates with all fields', () {
      final oldSel = const TextSelection.collapsed(offset: 5);
      final newSel = const TextSelection.collapsed(offset: 11);

      final entry = TextUndoEntry(
        oldText: 'Hello',
        newText: 'Hello World',
        oldSelection: oldSel,
        newSelection: newSel,
        description: 'Test change',
      );

      expect(entry.oldSelection, oldSel);
      expect(entry.newSelection, newSel);
      expect(entry.description, 'Test change');
    });

    test('uses provided timestamp', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30);

      final entry = TextUndoEntry(
        oldText: 'A',
        newText: 'B',
        timestamp: timestamp,
      );

      expect(entry.timestamp, timestamp);
    });

    test('insert factory creates correct entry', () {
      final entry = TextUndoEntry.insert(
        text: 'Hello',
        offset: 5,
        insertedText: ' World',
      );

      expect(entry.oldText, 'Hello');
      expect(entry.newText, 'Hello World');
      expect(entry.description, contains('Insert'));
    });

    test('insert factory handles middle insertion', () {
      final entry = TextUndoEntry.insert(
        text: 'Hello World',
        offset: 5,
        insertedText: ' Beautiful',
      );

      expect(entry.newText, 'Hello Beautiful World');
    });

    test('delete factory creates correct entry', () {
      final entry = TextUndoEntry.delete(
        text: 'Hello World',
        start: 5,
        end: 11,
      );

      expect(entry.oldText, 'Hello World');
      expect(entry.newText, 'Hello');
      expect(entry.description, contains('Delete'));
    });

    test('replace factory creates correct entry', () {
      final entry = TextUndoEntry.replace(
        oldText: 'Hello',
        newText: 'Goodbye',
        description: 'Replace greeting',
      );

      expect(entry.oldText, 'Hello');
      expect(entry.newText, 'Goodbye');
      expect(entry.description, 'Replace greeting');
    });

    test('replace factory with default description', () {
      final entry = TextUndoEntry.replace(
        oldText: 'A',
        newText: 'B',
      );

      expect(entry.description, 'Replace text');
    });

    test('insert truncates long text in description', () {
      final longText = 'A' * 50;
      final entry = TextUndoEntry.insert(
        text: '',
        offset: 0,
        insertedText: longText,
      );

      expect(entry.description, contains('...'));
      expect(entry.description!.length, lessThan(40));
    });

    test('delete truncates long text in description', () {
      final text = 'A' * 50;
      final entry = TextUndoEntry.delete(
        text: text,
        start: 0,
        end: 50,
      );

      expect(entry.description, contains('...'));
    });

    test('toString includes description and lengths', () {
      final entry = TextUndoEntry(
        oldText: 'Hello',
        newText: 'Hello World',
        description: 'Typed " World"',
      );

      final str = entry.toString();
      expect(str, contains('Typed'));
      expect(str, contains('5'));
      expect(str, contains('11'));
    });

    test('toString uses "change" when no description', () {
      final entry = TextUndoEntry(
        oldText: 'A',
        newText: 'AB',
      );

      expect(entry.toString(), contains('change'));
    });
  });
}
