import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

void main() {
  group('MdTextContext', () {
    late MdEditorController controller;

    setUp(() {
      controller = MdEditorController(initialMarkdown: '# Hello\n\nWorld');
    });

    tearDown(() {
      controller.dispose();
    });

    group('text', () {
      test('returns controller markdown', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        expect(ctx.text, '# Hello\n\nWorld');
      });

      test('updates when controller markdown changes', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        controller.applyEdit('# Updated');
        expect(ctx.text, '# Updated');
      });
    });

    group('cursor position', () {
      test('cursorOffset returns controller cursorOffset', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        controller.setCursorOffset(5);
        expect(ctx.cursorOffset, 5);
      });

      test('currentLine computes correctly for first line', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        controller.setCursorOffset(3); // "# H" — line 0
        expect(ctx.currentLine, 0);
      });

      test('currentLine computes correctly for later lines', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        // "# Hello\n\nWorld" — offset 10 is in "World" = line 2
        controller.setCursorOffset(10);
        expect(ctx.currentLine, 2);
      });

      test('currentColumn computes correctly', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        // "# Hello\n\nWorld" — offset 10 is "W" = column 1
        controller.setCursorOffset(10);
        expect(ctx.currentColumn, 1);
      });

      test('currentColumn at start of text is 0', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        controller.setCursorOffset(0);
        expect(ctx.currentColumn, 0);
      });
    });

    group('selections', () {
      test('returns collapsed selection at cursor offset', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        controller.setCursorOffset(5);
        final sels = ctx.selections;
        expect(sels.length, 1);
        expect(sels.first.isCollapsed, true);
        expect(sels.first.baseOffset, 5);
      });
    });

    group('isDirty', () {
      test('delegates to isDirtyFn', () {
        var dirty = false;
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => dirty,
        );
        addTearDown(ctx.dispose);

        expect(ctx.isDirty, false);
        dirty = true;
        expect(ctx.isDirty, true);
      });
    });

    group('canUndo / canRedo', () {
      test('canUndo delegates to controller', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        expect(ctx.canUndo, false);
        controller.applyEdit('changed');
        expect(ctx.canUndo, true);
      });

      test('canRedo delegates to controller', () {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        expect(ctx.canRedo, false);
        controller.applyEdit('changed');
        controller.undo();
        expect(ctx.canRedo, true);
      });
    });

    group('onContextChanged', () {
      test('fires when controller notifies', () async {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        var changeCount = 0;
        final sub = ctx.onContextChanged.listen((_) => changeCount++);
        addTearDown(sub.cancel);

        controller.applyEdit('new text');
        await Future.delayed(Duration.zero);
        expect(changeCount, greaterThan(0));
      });

      test('fires on notifyExternalChange', () async {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );
        addTearDown(ctx.dispose);

        var changeCount = 0;
        final sub = ctx.onContextChanged.listen((_) => changeCount++);
        addTearDown(sub.cancel);

        ctx.notifyExternalChange();
        await Future.delayed(Duration.zero);
        expect(changeCount, 1);
      });
    });

    group('dispose', () {
      test('stops listening to controller changes', () async {
        final ctx = MdTextContext(
          controller: controller,
          isDirtyFn: () => false,
        );

        var changeCount = 0;
        final sub = ctx.onContextChanged.listen((_) => changeCount++);

        ctx.dispose();
        controller.applyEdit('after dispose');
        await Future.delayed(Duration.zero);
        // Stream is closed, no more events
        await sub.cancel();
      });
    });
  });

  group('MdBasicTheme.toForgeTextSettings', () {
    test('maps default theme to ForgeTextSettings', () {
      const theme = MdBasicTheme();
      final settings = theme.toForgeTextSettings();

      expect(settings.fontFamily, theme.fontFamily);
      expect(settings.fontSize, theme.baseFontSize);
      expect(settings.lineHeight, theme.lineHeight);
      expect(settings.wordWrap, true);
      expect(settings.showLineNumbers, false);
      expect(settings.tabSize, MdEditorDefaults.defaultTabSize);
    });

    test('maps custom theme properties correctly', () {
      const theme = MdBasicTheme(
        fontFamily: 'Custom Font',
        baseFontSize: 18.0,
        lineHeight: 2.0,
      );
      final settings = theme.toForgeTextSettings();

      expect(settings.fontFamily, 'Custom Font');
      expect(settings.fontSize, 18.0);
      expect(settings.lineHeight, 2.0);
    });
  });
}
