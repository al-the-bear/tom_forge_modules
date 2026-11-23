import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show ForgeModule, ForgeShellApi;

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
/// The host gives the store (the app's is loaded from the workspace's review
/// file); the model future defaults to the bundled asset, and tests supply a
/// synthetic model.
class SpecStructureModule extends ForgeModule {
  SpecStructureModule({
    Future<SpecModel>? modelFuture,
    required ReviewStore store,
  }) : _store = store {
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
