import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('ForgeTextDefaults', () {
    test('has expected defaults', () {
      expect(ForgeTextDefaults.defaultFontSize, 14.0);
      expect(ForgeTextDefaults.defaultFontFamily, 'monospace');
      expect(ForgeTextDefaults.defaultLineHeight, 1.4);
      expect(ForgeTextDefaults.defaultTabSize, 2);
    });
  });

  group('ForgeTextSettings', () {
    test('creates with defaults', () {
      const settings = ForgeTextSettings();

      expect(settings.fontSize, ForgeTextDefaults.defaultFontSize);
      expect(settings.fontFamily, ForgeTextDefaults.defaultFontFamily);
      expect(settings.lineHeight, ForgeTextDefaults.defaultLineHeight);
      expect(settings.tabSize, ForgeTextDefaults.defaultTabSize);
      expect(settings.insertSpaces, true);
      expect(settings.wordWrap, true);
    });

    test('creates with custom values', () {
      const settings = ForgeTextSettings(
        fontSize: 16.0,
        fontFamily: 'Fira Code',
        lineHeight: 1.8,
        tabSize: 4,
        insertSpaces: false,
        wordWrap: false,
      );

      expect(settings.fontSize, 16.0);
      expect(settings.fontFamily, 'Fira Code');
      expect(settings.lineHeight, 1.8);
      expect(settings.tabSize, 4);
      expect(settings.insertSpaces, false);
      expect(settings.wordWrap, false);
    });

    test('toTextStyle creates valid TextStyle', () {
      const settings = ForgeTextSettings(
        fontSize: 14.0,
        fontFamily: 'monospace',
        lineHeight: 1.5,
      );

      final style = settings.toTextStyle(color: Colors.black);

      expect(style.fontSize, 14.0);
      expect(style.fontFamily, 'monospace');
      expect(style.height, 1.5);
      expect(style.color, Colors.black);
    });

    test('toTextStyle without color', () {
      const settings = ForgeTextSettings(
        fontSize: 12.0,
      );

      final style = settings.toTextStyle();

      expect(style.fontSize, 12.0);
      expect(style.color, isNull);
    });

    test('indentString returns spaces when insertSpaces', () {
      const settings = ForgeTextSettings(
        tabSize: 2,
        insertSpaces: true,
      );

      expect(settings.indentString, '  ');
    });

    test('indentString returns tab when not insertSpaces', () {
      const settings = ForgeTextSettings(
        tabSize: 4,
        insertSpaces: false,
      );

      expect(settings.indentString, '\t');
    });

    test('copyWith preserves unchanged fields', () {
      const original = ForgeTextSettings(
        fontSize: 14.0,
        fontFamily: 'Mono',
        tabSize: 2,
      );

      final copied = original.copyWith(fontSize: 16.0);

      expect(copied.fontSize, 16.0);
      expect(copied.fontFamily, 'Mono');
      expect(copied.tabSize, 2);
    });

    test('copyWith updates multiple fields', () {
      const original = ForgeTextSettings();

      final copied = original.copyWith(
        fontSize: 18.0,
        tabSize: 4,
        insertSpaces: false,
      );

      expect(copied.fontSize, 18.0);
      expect(copied.tabSize, 4);
      expect(copied.insertSpaces, false);
      expect(copied.fontFamily, ForgeTextDefaults.defaultFontFamily);
    });

    test('equality based on all fields', () {
      const settings1 = ForgeTextSettings(
        fontSize: 14.0,
        fontFamily: 'Mono',
      );
      const settings2 = ForgeTextSettings(
        fontSize: 14.0,
        fontFamily: 'Mono',
      );
      const settings3 = ForgeTextSettings(
        fontSize: 16.0,
        fontFamily: 'Mono',
      );

      expect(settings1, equals(settings2));
      expect(settings1, isNot(equals(settings3)));
    });

    test('hashCode consistent with equality', () {
      const settings1 = ForgeTextSettings(fontSize: 14.0);
      const settings2 = ForgeTextSettings(fontSize: 14.0);

      expect(settings1.hashCode, equals(settings2.hashCode));
    });

    test('toString includes key fields', () {
      const settings = ForgeTextSettings(
        fontSize: 14.0,
        fontFamily: 'Test Font',
      );

      final str = settings.toString();
      expect(str, contains('14.0'));
      expect(str, contains('Test Font'));
    });
  });
}
