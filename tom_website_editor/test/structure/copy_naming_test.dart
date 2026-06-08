import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

/// Tests for the website §16 copy-file naming convention used by the §6b
/// structure explorer: `home.md`, `<A>_area.md`, `<C>_component.md`,
/// `<C>_<M>_module.md`, `<C>_<M>_<S>_submodule.md`.
void main() {
  group('parseCopyFileName', () {
    // CN-01: home copy file.
    test('CN-01: home.md parses as the home copy', () {
      final parsed = parseCopyFileName('home.md');
      expect(parsed, isNotNull);
      expect(parsed!.kind, CopyFileKind.home);
      expect(parsed.parts, isEmpty);
    });

    // CN-02: area copy file.
    test('CN-02: <A>_area.md parses as an area copy', () {
      final parsed = parseCopyFileName('platform_area.md');
      expect(parsed!.kind, CopyFileKind.area);
      expect(parsed.parts, ['platform']);
    });

    // CN-03: component copy file.
    test('CN-03: <C>_component.md parses as a component copy', () {
      final parsed = parseCopyFileName('auth_component.md');
      expect(parsed!.kind, CopyFileKind.component);
      expect(parsed.parts, ['auth']);
    });

    // CN-04: module copy file.
    test('CN-04: <C>_<M>_module.md parses as a module copy', () {
      final parsed = parseCopyFileName('auth_login_module.md');
      expect(parsed!.kind, CopyFileKind.module);
      expect(parsed.parts, ['auth', 'login']);
    });

    // CN-05: submodule copy file.
    test('CN-05: <C>_<M>_<S>_submodule.md parses as a submodule copy', () {
      final parsed = parseCopyFileName('auth_login_oauth_submodule.md');
      expect(parsed!.kind, CopyFileKind.submodule);
      expect(parsed.parts, ['auth', 'login', 'oauth']);
    });

    // CN-06: a non-convention name is not a copy file.
    test('CN-06: a non-convention .md returns null', () {
      expect(parseCopyFileName('readme.md'), isNull);
      expect(parseCopyFileName('auth_component.yaml'), isNull);
    });

    // CN-07: a malformed convention name (wrong part count) returns null.
    test('CN-07: a malformed convention name returns null', () {
      // `_module` needs exactly component + module before the keyword.
      expect(parseCopyFileName('lonely_module.md'), isNull);
      expect(parseCopyFileName('module.md'), isNull);
    });
  });

  group('copyFileName', () {
    // CN-08: encode each kind back to the §16 filename.
    test('CN-08: encodes each kind to the convention filename', () {
      expect(copyFileName(CopyFileKind.home), 'home.md');
      expect(copyFileName(CopyFileKind.area, parts: ['platform']),
          'platform_area.md');
      expect(copyFileName(CopyFileKind.component, parts: ['auth']),
          'auth_component.md');
      expect(copyFileName(CopyFileKind.module, parts: ['auth', 'login']),
          'auth_login_module.md');
      expect(
          copyFileName(CopyFileKind.submodule, parts: ['auth', 'login', 'o']),
          'auth_login_o_submodule.md');
    });

    // CN-09: encode↔parse round-trips for every kind.
    test('CN-09: encode then parse round-trips', () {
      for (final (kind, parts) in const [
        (CopyFileKind.home, <String>[]),
        (CopyFileKind.area, ['ui']),
        (CopyFileKind.component, ['auth']),
        (CopyFileKind.module, ['auth', 'login']),
        (CopyFileKind.submodule, ['auth', 'login', 'oauth']),
      ]) {
        final name = copyFileName(kind, parts: parts);
        final parsed = parseCopyFileName(name)!;
        expect(parsed.kind, kind);
        expect(parsed.parts, parts);
      }
    });
  });

  group('groupCopyFiles', () {
    // CN-10: flat copy files group into a component → module → submodule tree
    // plus an areas group and the home file.
    test('CN-10: groups copy files into a structured tree', () {
      final base = Uri.parse('file:///site/content/copy/');
      final files = [
        base.resolve('home.md'),
        base.resolve('platform_area.md'),
        base.resolve('auth_component.md'),
        base.resolve('auth_login_module.md'),
        base.resolve('auth_login_oauth_submodule.md'),
        base.resolve('billing_component.md'),
      ];

      final nodes = groupCopyFiles(files);

      // Top level: auth (component), billing (component), an areas group, home.
      final labels = nodes.map((n) => n.label).toList();
      expect(labels, containsAll(['auth', 'billing', 'areas', 'home']));

      final auth = nodes.firstWhere((n) => n.label == 'auth');
      // auth carries its own component file and a `login` module child.
      expect(auth.uri, base.resolve('auth_component.md'));
      final login = auth.children.firstWhere((n) => n.label == 'login');
      expect(login.uri, base.resolve('auth_login_module.md'));
      final oauth = login.children.firstWhere((n) => n.label == 'oauth');
      expect(oauth.uri, base.resolve('auth_login_oauth_submodule.md'));

      final areas = nodes.firstWhere((n) => n.label == 'areas');
      expect(areas.children.single.uri, base.resolve('platform_area.md'));

      final home = nodes.firstWhere((n) => n.label == 'home');
      expect(home.uri, base.resolve('home.md'));
    });

    // CN-11: files that don't match the convention are surfaced verbatim as
    // top-level file nodes (never dropped).
    test('CN-11: non-convention files are kept as plain file nodes', () {
      final base = Uri.parse('file:///site/content/copy/');
      final nodes = groupCopyFiles([base.resolve('notes.md')]);
      expect(nodes.single.label, 'notes.md');
      expect(nodes.single.uri, base.resolve('notes.md'));
    });
  });
}
