/// The module context-menu model (woneqrb13): a target, its own items, and a
/// contribution that places an action at a target kind.
library;

import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:test/test.dart';

void main() {
  group('ForgeContextTarget', () {
    test('WONEQRB13-C1: carries its kind, data and own items, and names the '
        'parameter key the shell passes it under', () {
      final target = ForgeContextTarget(
        kind: ForgeContextTarget.explorerFileKind,
        data: Uri.file('/w/a.txt'),
        items: [
          ForgeContextMenuItem(id: 'x.one', label: 'One', run: () async {}),
        ],
      );
      expect(target.kind, 'forge.explorer.file');
      expect(target.data, Uri.file('/w/a.txt'));
      expect(target.items.single.id, 'x.one');
      expect(target.items.single.enabled, isTrue);
      expect(target.items.single.unavailableReason, isNull);
      expect(ForgeContextTarget.parameterKey, 'contextTarget');
      expect(ForgeContextTarget.explorerDirectoryKind,
          'forge.explorer.directory');
      expect(target.toString(), contains('forge.explorer.file'));
    });
  });

  group('ForgeContextMenuContribution', () {
    test('WONEQRB13-C2: a bare contribution applies everywhere of its kind '
        'and defers label and enablement to the action', () {
      const contribution = ForgeContextMenuContribution(
        targetKind: 'fake.unit',
        actionId: 'fake.act',
      );
      expect(contribution.isApplicable, isNull);
      expect(contribution.label, isNull);
      expect(contribution.unavailableReason, isNull);
      expect(contribution.group, isNull);
      expect(contribution.toString(), 'ForgeContextMenuContribution(fake.unit → fake.act)');
    });

    test('WONEQRB13-C3: the predicates read the target', () {
      final contribution = ForgeContextMenuContribution(
        targetKind: 'fake.unit',
        actionId: 'fake.act',
        group: 'g',
        isApplicable: (t) => t.data is int,
        label: (t) => 'Act on ${t.data}',
        unavailableReason: (t) => (t.data as int) > 2 ? 'too big' : null,
      );
      const small = ForgeContextTarget(kind: 'fake.unit', data: 1);
      const big = ForgeContextTarget(kind: 'fake.unit', data: 3);
      const other = ForgeContextTarget(kind: 'fake.unit', data: 'no');
      expect(contribution.isApplicable!(small), isTrue);
      expect(contribution.isApplicable!(other), isFalse);
      expect(contribution.label!(small), 'Act on 1');
      expect(contribution.unavailableReason!(small), isNull);
      expect(contribution.unavailableReason!(big), 'too big');
    });
  });
}
