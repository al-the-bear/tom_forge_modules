import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import '../structure/spec_model.dart';
import 'spec_document_controller.dart';

/// The selector segment for a root: its section id, falling back to its type.
String rootSelector(SpecRoot root) => root.sectionId ?? root.type;

/// Whether [root] is the Project Definition (the canonical, shared root).
bool isProjectDefinition(SpecRoot root) =>
    root.type == 'ProjectDefinition' || root.sectionId == 'PD';

/// The default root the editor opens on when nothing is selected (§14): the
/// Project Definition if the model has one, else the model's first root (so a
/// single-root synthetic model still resolves sensibly).
SpecRoot? defaultNavigatorRoot(List<SpecRoot> roots) {
  if (roots.isEmpty) return null;
  for (final r in roots) {
    if (isProjectDefinition(r)) return r;
  }
  return roots.first;
}

/// Orders roots for the §14 navigator: **Project Definition first**, then the
/// remaining roots **alphabetically by title**. The navigator renders a
/// separator after Project Definition; this pure ordering keeps that policy
/// testable independently of the widget.
List<SpecRoot> navigatorRootOrder(List<SpecRoot> roots) {
  final pd = <SpecRoot>[];
  final others = <SpecRoot>[];
  for (final r in roots) {
    (isProjectDefinition(r) ? pd : others).add(r);
  }
  others.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return [...pd, ...others];
}

/// The §14 root navigator, surfaced as the DocSpecs left-panel "Navigator" tab.
///
/// Lists the document roots (Project Definition first, a separator, then the
/// rest alphabetically) and drives the *active root* on the shared
/// [SpecDocumentController]. Selecting a root re-renders the document editor as
/// that projection over the **same** underlying document — switching never
/// copies or forks data (step 20 / §14).
class RootNavigator extends ForgeView {
  RootNavigator({required this.controller})
      : _title = ValueNotifier<String>('Navigator'),
        _titleExtension = ValueNotifier<String?>(null);

  /// The shared controller whose active root this navigator drives.
  final SpecDocumentController controller;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;

  @override
  IconData get icon => Icons.account_tree_outlined;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) =>
      RootNavigatorList(controller: controller);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// The navigator's body: the ordered, selectable list of document roots.
class RootNavigatorList extends StatelessWidget {
  const RootNavigatorList({super.key, required this.controller});

  final SpecDocumentController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpecModel>(
      future: controller.ensureLoaded(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load model:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          );
        }
        final model = snapshot.data;
        if (model == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final ordered = navigatorRootOrder(model.roots);
        final fallback = defaultNavigatorRoot(model.roots);
        // Rebuild the highlight whenever the active root changes.
        return Column(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final active = controller.activeRootType ??
                      (fallback != null ? rootSelector(fallback) : null);
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: ordered.length,
                    itemBuilder: (context, i) {
                      final root = ordered[i];
                      final seg = rootSelector(root);
                      final selected = seg == active ||
                          root.type == active ||
                          root.sectionId == active;
                      // A separator sits after Project Definition (index 0 when
                      // the model has a PD root), before the alphabetical rest.
                      final showDivider = i == 0 &&
                          ordered.length > 1 &&
                          isProjectDefinition(root);
                      final tile = _RootTile(
                        root: root,
                        selected: selected,
                        onTap: () => controller.setActiveRoot(seg),
                      );
                      if (!showDivider) return tile;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [tile, const Divider(height: 1)],
                      );
                    },
                  );
                },
              ),
            ),
            _ModelVersionFooter(model: model),
          ],
        );
      },
    );
  }
}

/// A compact footer reporting the model-version stamp the bundled
/// `spec_model.json` was generated against (§17, B2). Makes model drift
/// observable from the running app: an official build shows e.g. `model v3
/// · 1.0.0+3.abc1234`; an unstamped manual export shows `model: unstamped`.
class _ModelVersionFooter extends StatelessWidget {
  const _ModelVersionFooter({required this.model});

  final SpecModel model;

  /// The user-facing string for [model]'s stamp.
  static String label(SpecModel model) {
    if (model.modelVersion <= 0) return 'model: unstamped';
    final suffix =
        model.modelVersionLabel != null ? ' · ${model.modelVersionLabel}' : '';
    return 'model v${model.modelVersion}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Text(
        label(model),
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// One selectable root row.
class _RootTile extends StatelessWidget {
  const _RootTile({
    required this.root,
    required this.selected,
    required this.onTap,
  });

  final SpecRoot root;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.4,
      ),
      leading: Text(
        rootSelector(root),
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
      ),
      title: Text(root.title, style: const TextStyle(fontSize: 13)),
      onTap: onTap,
    );
  }
}
