import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import '../structure/spec_model.dart';
import 'spec_document_controller.dart';

/// The selector segment for a root: its section id, falling back to its type.
String rootSelector(SpecRoot root) => root.sectionId ?? root.type;

/// Whether [root] is the Solution Blueprint (the canonical, shared master root).
bool isSolutionBlueprint(SpecRoot root) =>
    root.type == 'SolutionBlueprint' || root.sectionId == 'SBP';

/// The heading of the navigator's second band
/// (`tom_specs_editor_specification.md` §14).
const String kGenerationInputsBandLabel = 'Generation inputs';

/// The default root the editor opens on when nothing is selected
/// (`tom_specs_editor_specification.md` §14): the Solution Blueprint if the
/// model has one, else the first **authored** root, else the model's first root
/// (so a single-root synthetic model still resolves sensibly).
///
/// A generation input is never the default landing root — opening the editor on
/// the CodeSpecs projection would present a generator's input as the thing the
/// user came to write.
SpecRoot? defaultNavigatorRoot(SpecModel model) {
  final roots = model.roots;
  if (roots.isEmpty) return null;
  for (final r in roots) {
    if (isSolutionBlueprint(r)) return r;
  }
  for (final r in roots) {
    if (!model.isGenerationInput(r)) return r;
  }
  return roots.first;
}

/// Orders roots for the `tom_specs_editor_specification.md` §14 navigator, in
/// **two bands**:
///
/// 1. the **authored documents** — Solution Blueprint first, then the Phase-3
///    projections alphabetically by title;
/// 2. the **generation inputs** — [SpecModel.isGenerationInput] roots, also
///    alphabetically, below a labelled heading.
///
/// The second band exists because a generation input is not a document. Listing
/// `D13CodeSpecsProjection` as a peer of RSP and IFM states that the spec has
/// fourteen documents to author, when it has thirteen plus one projection whose
/// reader is the Phase-4 generator. The band is a **presentational** split
/// only: generation-input roots stay selectable and editable, because an edit
/// made through any projection folds onto the same Solution Blueprint storage
/// path (§14, storage-path key) — the same edit is one click away under the
/// blueprint, so forbidding it here would protect nothing.
///
/// The ordering takes the whole [model], not just its roots, because the
/// classification lives on the root's *class* annotations. Passing roots alone
/// would make the band silently droppable at a call site that forgot it.
List<SpecRoot> navigatorRootOrder(SpecModel model) {
  final master = <SpecRoot>[];
  final authored = <SpecRoot>[];
  final generationInputs = <SpecRoot>[];
  for (final r in model.roots) {
    if (isSolutionBlueprint(r)) {
      master.add(r);
    } else if (model.isGenerationInput(r)) {
      generationInputs.add(r);
    } else {
      authored.add(r);
    }
  }
  int byTitle(SpecRoot a, SpecRoot b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  authored.sort(byTitle);
  generationInputs.sort(byTitle);
  return [...master, ...authored, ...generationInputs];
}

/// The `tom_specs_editor_specification.md` §14 root navigator, surfaced as the
/// DocSpecs left-panel "Navigator" tab.
///
/// Lists the document roots (Solution Blueprint first, a separator, then the
/// rest alphabetically) and drives the *active root* on the shared
/// [SpecDocumentController]. Selecting a root re-renders the document editor as
/// that projection over the **same** underlying document — switching never
/// copies or forks data (step 20 / `tom_specs_editor_specification.md` §14).
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
        final ordered = navigatorRootOrder(model);
        final fallback = defaultNavigatorRoot(model);
        // Index of the first generation input in `ordered`, or -1 when the
        // model has none. The band heading is drawn immediately above it.
        final bandStart = ordered.indexWhere(model.isGenerationInput);
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
                      // A separator sits after the Solution Blueprint (index 0
                      // when the model has one), before the alphabetical rest.
                      final showDivider = i == 0 &&
                          ordered.length > 1 &&
                          isSolutionBlueprint(root);
                      final tile = _RootTile(
                        root: root,
                        selected: selected,
                        onTap: () => controller.setActiveRoot(seg),
                      );
                      // The generation-inputs band opens here.
                      if (i == bandStart) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Divider(height: 1),
                            const _BandHeading(kGenerationInputsBandLabel),
                            tile,
                          ],
                        );
                      }
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

/// A band heading in the root navigator — the label that separates the authored
/// documents from the generation inputs (`tom_specs_editor_specification.md`
/// §14). Non-interactive: it names a category, it is not a selectable root.
class _BandHeading extends StatelessWidget {
  const _BandHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// A compact footer reporting the model-version stamp the bundled
/// `spec_model.json` was generated against (`tom_specs_editor_specification.md`
/// §17, B2). Makes model drift observable from the running app: an official
/// build shows e.g. `model v3 · 1.0.0+3.abc1234`; an unstamped manual export
/// shows `model: unstamped`.
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
