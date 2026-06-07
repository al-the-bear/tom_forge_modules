// WebsiteEditorController — the async/notify layer over WebsiteRegistry (§9.2).
//
// The registry semantics (load/select/reload/last-good) are proven in
// tom_website_editor_core; these tests cover the controller's added behaviour:
// async config reading, loading flag, change notifications, and that an invalid
// reload keeps the last-good registry while exposing the new issues (§6).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

const _twoSites = '''
version: 1
websites:
  - id: alpha
    label: Alpha
    paths: { websiteRoot: "/a" }
  - id: beta
    paths: { websiteRoot: "/b" }
''';

const _invalid = 'version: 1\nwebsites: []\n';

/// A config reader returning whatever [source] currently points at, counting
/// how many times it was invoked.
class _StubReader {
  _StubReader(this.source);
  String source;
  int calls = 0;

  Future<String> read() async {
    calls++;
    return source;
  }
}

void main() {
  group('WebsiteEditorController.load', () {
    test('TWE-CTL-01: valid source builds the registry, active defaults first',
        () async {
      final reader = _StubReader(_twoSites);
      final controller =
          WebsiteEditorController(configReader: reader.read);
      final ok = await controller.load();
      expect(ok, isTrue);
      expect(controller.isLoaded, isTrue);
      expect(controller.websites.map((w) => w.id), ['alpha', 'beta']);
      expect(controller.activeWebsiteId, 'alpha');
      expect(controller.issues, isEmpty);
    });

    test('TWE-CTL-02: invalid source leaves controller unloaded + issues',
        () async {
      final controller =
          WebsiteEditorController(configReader: _StubReader(_invalid).read);
      final ok = await controller.load();
      expect(ok, isFalse);
      expect(controller.isLoaded, isFalse);
      expect(controller.activeWebsiteId, isNull);
      expect(
        controller.issues.any((i) => i.severity == ConfigSeverity.error),
        isTrue,
      );
    });

    test('TWE-CTL-03: notifies listeners and toggles isLoading', () async {
      final controller =
          WebsiteEditorController(configReader: _StubReader(_twoSites).read);
      var notifications = 0;
      final loadingStates = <bool>[];
      controller.addListener(() {
        notifications++;
        loadingStates.add(controller.isLoading);
      });
      await controller.load();
      expect(notifications, greaterThanOrEqualTo(2));
      expect(loadingStates.first, isTrue); // entered loading
      expect(loadingStates.last, isFalse); // settled
      expect(controller.isLoading, isFalse);
    });
  });

  group('WebsiteEditorController.selectWebsite', () {
    test('TWE-CTL-04: selecting a known id changes active and notifies',
        () async {
      final controller =
          WebsiteEditorController(configReader: _StubReader(_twoSites).read);
      await controller.load();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.selectWebsite('beta');
      expect(controller.activeWebsiteId, 'beta');
      expect(notified, isTrue);
    });

    test('TWE-CTL-05: selecting before load is a no-op', () {
      final controller =
          WebsiteEditorController(configReader: _StubReader(_twoSites).read);
      controller.selectWebsite('beta'); // must not throw
      expect(controller.activeWebsiteId, isNull);
    });
  });

  group('WebsiteEditorController.reload', () {
    test('TWE-CTL-06: reload before load delegates to load', () async {
      final reader = _StubReader(_twoSites);
      final controller = WebsiteEditorController(configReader: reader.read);
      final applied = await controller.reload();
      expect(applied, isTrue);
      expect(controller.isLoaded, isTrue);
      expect(reader.calls, 1);
    });

    test('TWE-CTL-07: valid reload re-reads source and preserves active id',
        () async {
      final reader = _StubReader(_twoSites);
      final controller = WebsiteEditorController(configReader: reader.read);
      await controller.load();
      controller.selectWebsite('beta');
      reader.source = '''
version: 1
websites:
  - id: alpha
    paths: { websiteRoot: "/a2" }
  - id: beta
    paths: { websiteRoot: "/b2" }
''';
      final applied = await controller.reload();
      expect(applied, isTrue);
      expect(controller.activeWebsiteId, 'beta');
      expect(controller.registry!.activeWebsite.paths['websiteRoot'], '/b2');
      expect(reader.calls, 2);
    });

    test('TWE-CTL-08: invalid reload keeps last-good registry, exposes issues',
        () async {
      final reader = _StubReader(_twoSites);
      final controller = WebsiteEditorController(configReader: reader.read);
      await controller.load();
      controller.selectWebsite('beta');
      reader.source = _invalid;
      final applied = await controller.reload();
      expect(applied, isFalse);
      // last-good preserved
      expect(controller.websites.map((w) => w.id), ['alpha', 'beta']);
      expect(controller.activeWebsiteId, 'beta');
      expect(
        controller.issues.any((i) => i.severity == ConfigSeverity.error),
        isTrue,
      );
    });
  });

  group('WebsiteEditorController read-failure handling', () {
    // The reader is wired to ForgeShellApi.fileSystem.read, which throws when
    // the config file is absent. A missing/unreadable config is a load failure,
    // not a crash: it must surface as an error issue (so default-startup
    // wiring that runs load() unawaited never throws into the zone).
    Future<String> throwingReader() =>
        Future<String>.error(const FileSystemException('no such file'));

    test('TWE-CTL-09: load surfaces a read failure as an error issue', () async {
      final controller = WebsiteEditorController(configReader: throwingReader);
      final ok = await controller.load();
      expect(ok, isFalse);
      expect(controller.isLoaded, isFalse);
      expect(controller.isLoading, isFalse);
      expect(
        controller.issues.any((i) => i.severity == ConfigSeverity.error),
        isTrue,
      );
    });

    test('TWE-CTL-10: reload before load surfaces a read failure, no throw',
        () async {
      final controller = WebsiteEditorController(configReader: throwingReader);
      final applied = await controller.reload();
      expect(applied, isFalse);
      expect(controller.isLoaded, isFalse);
      expect(
        controller.issues.any((i) => i.severity == ConfigSeverity.error),
        isTrue,
      );
    });

    test('TWE-CTL-12: a load settling after dispose does not notify/throw',
        () async {
      // On shell teardown the module is deactivated (controller disposed) which
      // can race an initial load() still in flight. The settling load must not
      // call notifyListeners() on the disposed controller.
      final controller = WebsiteEditorController(configReader: throwingReader);
      final pending = controller.load();
      controller.dispose();
      expect(await pending, isFalse);
    });

    test('TWE-CTL-11: read failure on reload keeps the last-good registry',
        () async {
      var fail = false;
      final controller = WebsiteEditorController(
        configReader: () =>
            fail ? throwingReader() : Future<String>.value(_twoSites),
      );
      await controller.load();
      expect(controller.isLoaded, isTrue);

      fail = true;
      final applied = await controller.reload();
      expect(applied, isFalse);
      // last-good registry preserved despite the read failure
      expect(controller.websites.map((w) => w.id), ['alpha', 'beta']);
      expect(
        controller.issues.any((i) => i.severity == ConfigSeverity.error),
        isTrue,
      );
    });
  });
}
