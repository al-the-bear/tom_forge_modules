import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'structure/review_store.dart';
import 'structure/spec_model.dart';
import 'structure/spec_structure_view.dart';

/// Module contributing the structure browser + structural review
/// (`tom_specs_editor_specification.md` §4.2, Q1).
///
/// Owns the [ReviewStore] (persisted to YAML) and the [SpecStructureView]. The
/// view is exposed through [structureView] so the shell module can host it as a
/// tab in the DocSpecs left panel.
///
/// The model future and store are injectable: the app uses the bundled asset
/// and the default review file, while tests supply a synthetic model and a
/// temp-file store.
class SpecStructureModule extends ForgeModule {
  SpecStructureModule({Future<SpecModel>? modelFuture, ReviewStore? store})
    : _store = store ?? (ReviewStore.resolveDefault()..load()) {
    _view = SpecStructureView(
      modelFuture: modelFuture ?? loadSpecModelFromAsset(),
      store: _store,
    );
    _views = [_view];
  }

  final ReviewStore _store;
  late final SpecStructureView _view;
  late final List<ForgeView> _views;

  /// The structure browser view, for hosting in a panel tab.
  SpecStructureView get structureView => _view;

  /// The structural-review store backing the view.
  ReviewStore get store => _store;

  @override
  String get displayName => 'TomSpecs Structure';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => _views;

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}
