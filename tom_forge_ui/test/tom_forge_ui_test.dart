import 'package:flutter_test/flutter_test.dart';

import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  test('ForgeComponentSizeHints defaults', () {
    const hints = ForgeComponentSizeHints();
    expect(hints.minSize.width, 120);
    expect(hints.preferredSize.width, 260);
  });

  test('AutoSaveConfig defaults', () {
    const config = AutoSaveConfig();
    expect(config.enabled, isTrue);
    expect(config.idleDelay, const Duration(seconds: 1));
    expect(config.saveOnFocusLoss, isTrue);
  });

  test('ForgeConfig defaults', () {
    const config = ForgeConfig();
    expect(config.autoSave.enabled, isTrue);
  });

  test('ForgeApplication tracks active state', () {
    final app = ForgeApplication(title: 'Test');
    expect(app.isActive, isFalse);
    app.isActive = true;
    expect(app.isActive, isTrue);
  });

  test('ForgeStartupPreferences defaults', () {
    final prefs = ForgeStartupPreferences();
    expect(prefs.rememberSettings, isTrue);
    expect(prefs.recentWorkspaces, isEmpty);
  });

  test('LayoutPanelConfig defaults', () {
    const config = LayoutPanelConfig();
    expect(config.size, 250);
    expect(config.isVisible, isTrue);
  });

  // ─── DefaultDialogManager ───────────────────────────────

  group('DefaultDialogManager', () {
    late DefaultDialogManager mgr;

    setUp(() {
      mgr = DefaultDialogManager();
    });

    test('showQuickPick returns first item when no callback', () async {
      final items = [
        ForgeQuickPickItem(label: 'A', value: 'a'),
        ForgeQuickPickItem(label: 'B', value: 'b'),
      ];
      final result = await mgr.showQuickPick(items);
      expect(result, 'a');
    });

    test('showQuickPick returns null for empty list', () async {
      final result = await mgr.showQuickPick<String>([]);
      expect(result, isNull);
    });

    test('showQuickPick delegates to callback', () async {
      mgr.onQuickPick = <T>(items, {placeholder, canSelectMany = false}) async {
        return items.last.value;
      };
      final items = [
        ForgeQuickPickItem(label: 'A', value: 'a'),
        ForgeQuickPickItem(label: 'B', value: 'b'),
      ];
      final result = await mgr.showQuickPick(items);
      expect(result, 'b');
    });

    test('showInputBox returns value when no callback', () async {
      final result = await mgr.showInputBox(value: 'hello');
      expect(result, 'hello');
    });

    test('showInputBox delegates to callback', () async {
      mgr.onInputBox = ({prompt, value, placeholder, validateInput}) async {
        return 'custom-$value';
      };
      final result = await mgr.showInputBox(value: 'test');
      expect(result, 'custom-test');
    });

    test('showOpenDialog returns null when no callback', () async {
      final result = await mgr.showOpenDialog();
      expect(result, isNull);
    });

    test('showOpenDialog delegates to callback', () async {
      mgr.onOpenDialog =
          ({title, canSelectMany = false, canSelectFolders = false, filters}) async {
        return [Uri.parse('file:///test.txt')];
      };
      final result = await mgr.showOpenDialog();
      expect(result, hasLength(1));
      expect(result!.first.path, '/test.txt');
    });

    test('showSaveDialog returns null when no callback', () async {
      final result = await mgr.showSaveDialog();
      expect(result, isNull);
    });

    test('showSaveDialog delegates to callback', () async {
      mgr.onSaveDialog = ({title, defaultUri, filters}) async {
        return Uri.parse('file:///saved.txt');
      };
      final result = await mgr.showSaveDialog();
      expect(result, isNotNull);
      expect(result!.path, '/saved.txt');
    });

    test('showQuickPick handles callback error gracefully', () async {
      mgr.onQuickPick = <T>(items, {placeholder, canSelectMany = false}) async {
        throw Exception('test error');
      };
      final result = await mgr.showQuickPick([
        ForgeQuickPickItem(label: 'A', value: 'a'),
      ]);
      expect(result, isNull);
    });

    test('showInputBox handles callback error gracefully', () async {
      mgr.onInputBox = ({prompt, value, placeholder, validateInput}) async {
        throw Exception('test error');
      };
      final result = await mgr.showInputBox(value: 'test');
      expect(result, isNull);
    });

    test('showOpenDialog handles callback error gracefully', () async {
      mgr.onOpenDialog =
          ({title, canSelectMany = false, canSelectFolders = false, filters}) async {
        throw Exception('test error');
      };
      final result = await mgr.showOpenDialog();
      expect(result, isNull);
    });

    test('showSaveDialog handles callback error gracefully', () async {
      mgr.onSaveDialog = ({title, defaultUri, filters}) async {
        throw Exception('test error');
      };
      final result = await mgr.showSaveDialog();
      expect(result, isNull);
    });
  });
}
