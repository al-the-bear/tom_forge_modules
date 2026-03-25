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
}
