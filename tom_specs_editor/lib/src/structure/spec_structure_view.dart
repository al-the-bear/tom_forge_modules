import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'review_store.dart';
import 'spec_model.dart';
import 'spec_tree.dart';

/// Loads the bundled class-graph model (`assets/spec_model.json`, produced by
/// `tom_specs_clitool/bin/model_json.dart`) and parses it into a [SpecModel].
///
/// Exposed as a free function so the [SpecStructureModule] can hand the future
/// to its view at construction, while tests can inject a synthetic model
/// instead of touching the asset bundle.
Future<SpecModel> loadSpecModelFromAsset() async {
  final raw = await rootBundle.loadString('assets/spec_model.json');
  return SpecModel.fromJson(json.decode(raw) as Map<String, dynamic>);
}

/// The structure browser + structural review, surfaced as a Forge panel view
/// (§4.2 — `SpecStructureModule`).
///
/// Ported from the standalone prototype's `StartPage` (step 10). The prototype
/// was a full-window master-detail page; here the same [SpecTree] is reused
/// inside a narrow, panel-friendly column (root selector + cut toggles +
/// scrolling tree) so it fits the DocSpecs left panel. The model is loaded
/// asynchronously and the review state persists through a [ReviewStore].
class SpecStructureView extends ForgeView {
  SpecStructureView({required this.modelFuture, required this.store})
      : _title = ValueNotifier<String>('Structure'),
        _titleExtension = ValueNotifier<String?>(null);

  /// The class-graph model to browse (asset-backed in the app, synthetic in
  /// tests).
  final Future<SpecModel> modelFuture;

  /// Persistent structural-review store, keyed by structural path.
  final ReviewStore store;

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
      _SpecStructureBrowser(modelFuture: modelFuture, store: store);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// Panel-friendly structure browser: a root selector and cut toggles stacked
/// above the [SpecTree] for the selected document root.
class _SpecStructureBrowser extends StatefulWidget {
  final Future<SpecModel> modelFuture;
  final ReviewStore store;

  const _SpecStructureBrowser({
    required this.modelFuture,
    required this.store,
  });

  @override
  State<_SpecStructureBrowser> createState() => _SpecStructureBrowserState();
}

class _SpecStructureBrowserState extends State<_SpecStructureBrowser> {
  SpecModel? _model;
  Object? _error;

  SpecRoot? _selected;

  /// 2b: suppress subsections at `@DetailedIn` hand-off points.
  bool _cutAtDetails = false;

  /// 2d: suppress subsections at `@MapsTo` hand-off points.
  bool _cutAtMaps = false;

  /// 2c: class to reveal/scroll-to after a hand-off jump (cleared on manual
  /// document selection).
  String? _navTargetType;

  @override
  void initState() {
    super.initState();
    widget.modelFuture.then((model) {
      if (!mounted) return;
      setState(() {
        _model = model;
        _selected = model.roots.isNotEmpty ? model.roots.first : null;
      });
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() => _error = error);
    });
  }

  void _selectRoot(SpecRoot? root, {String? navTargetType}) {
    setState(() {
      _selected = root;
      _navTargetType = navTargetType;
    });
  }

  /// Handles a hand-off marker tap: switch to [targetRoot] and reveal
  /// [targetType] within it.
  void _onHandoffTap(String targetRoot, String targetType) {
    final model = _model;
    if (model == null) return;
    SpecRoot? root;
    for (final r in model.roots) {
      if (r.type == targetRoot) {
        root = r;
        break;
      }
    }
    if (root == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No document for "$targetRoot"')),
      );
      return;
    }
    _selectRoot(root, navTargetType: targetType);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load spec model:\n$_error',
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final model = _model;
    if (model == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: _RootSelector(
            roots: model.roots,
            selected: _selected,
            onChanged: (root) => _selectRoot(root),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CutToggle(
                label: 'Cut at detail hand-offs',
                value: _cutAtDetails,
                color: Colors.deepOrangeAccent,
                onChanged: (v) => setState(() => _cutAtDetails = v),
              ),
              _CutToggle(
                label: 'Cut at maps hand-offs',
                value: _cutAtMaps,
                color: Colors.purpleAccent,
                onChanged: (v) => setState(() => _cutAtMaps = v),
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.store.count} reviewed',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _selected == null
              ? Center(
                  child: Text(
                    'Select a document to browse its structure',
                    style:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : SpecTree(
                  key: ValueKey(_selected!.type),
                  model: model,
                  root: _selected!,
                  store: widget.store,
                  cutAtDetails: _cutAtDetails,
                  cutAtMaps: _cutAtMaps,
                  navTargetType: _navTargetType,
                  onHandoffTap: _onHandoffTap,
                ),
        ),
      ],
    );
  }
}

/// Compact full-width document-root selector.
class _RootSelector extends StatelessWidget {
  final List<SpecRoot> roots;
  final SpecRoot? selected;
  final ValueChanged<SpecRoot?> onChanged;

  const _RootSelector({
    required this.roots,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<SpecRoot>(
      initialValue: selected,
      isExpanded: true,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'Document',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      items: [
        for (final root in roots)
          DropdownMenuItem<SpecRoot>(
            value: root,
            child: Text(
              root.sectionId != null
                  ? '${root.sectionId} · ${root.title}'
                  : root.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// A compact labelled switch used in the cut toolbar. The [color] dot ties the
/// switch to its hand-off marker colour (orange = detail, purple = maps).
class _CutToggle extends StatelessWidget {
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _CutToggle({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
