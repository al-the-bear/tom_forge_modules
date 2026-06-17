import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'placeholder_components.dart';

/// Bootstrap module for the TomSpecs Editor (§4.2).
///
/// Registers the three top-level [ForgeApplication]s — **DocSpecs**,
/// **CodeSpecs**, **Implementation** — and the common 4-region layout
/// skeleton (§5). The application switcher in the shell toolbar reads the
/// registered set from [DefaultSystemState.applications]; selecting one calls
/// the host's `onApplicationSwitch`, which re-renders the scaffold with the
/// chosen application's layout.
///
/// Only **DocSpecs** is functional in step 9: its four regions are populated
/// with placeholder views/editors so the layout is visible. CodeSpecs and
/// Implementation reuse the same skeleton with an empty document editor
/// (§5 — "CodeSpecs/Implementation apps reuse the skeleton with an empty
/// document editor"). The real `SpecDocumentEditor`, structure browser, chat
/// suite, and change log arrive in later steps (10–18).
class SpecsShellModule extends ForgeModule {
  SpecsShellModule({
    this.structureView,
    this.chatView,
    this.documentEditor,
    this.navigatorView,
  });

  /// The model-driven document editor (§13), hosted as the DocSpecs middle
  /// "Document" split when provided. Null in the skeleton tests that predate
  /// step 19, where the split falls back to a [PlaceholderEditor].
  final ForgeEditor? documentEditor;

  /// The §14 root navigator (step 20), hosted as the DocSpecs left panel's
  /// "Navigator" tab when provided. Null in the skeleton tests that predate
  /// step 20, where the tab falls back to a labelled placeholder.
  final ForgeView? navigatorView;

  /// The structure browser view (from [SpecStructureModule]), hosted as the
  /// DocSpecs left panel's "Structure" tab when provided (§5 — left panel's
  /// optional second tab = the document/section explorer). Null in the bare
  /// skeleton tests that predate step 10.
  final ForgeView? structureView;

  /// The agent chat view (from [AgentChatModule]), hosted as the DocSpecs
  /// bottom panel's "Chat" tab when provided (§5 — bottom panel = the chat
  /// suite). In step 11 it carries the connection picker only; the composer,
  /// streaming output, queue and trail arrive in later steps. Falls back to a
  /// labelled placeholder in the bare skeleton tests that predate step 11.
  final ForgeView? chatView;

  final List<ForgeView> _views = [];
  final List<ForgeEditor> _editors = [];
  final List<ForgeApplication> _applications = [];

  @override
  String get displayName => 'TomSpecs Shell';

  /// The DocSpecs application — the one shown on launch.
  late final ForgeApplication docSpecs;

  @override
  void activate(ForgeShellApi shell) {
    _buildApplications();
    final systemState = shell.systemState as DefaultSystemState;
    systemState.setApplications(_applications);
    systemState.setActiveApplication(docSpecs);
  }

  void _buildApplications() {
    docSpecs = _buildApp(
      title: 'DocSpecs',
      icon: Icons.description_outlined,
      documentTitle: 'Document',
      populated: true,
    )..isActive = true;

    final codeSpecs = _buildApp(
      title: 'CodeSpecs',
      icon: Icons.code_outlined,
      documentTitle: 'CodeSpec',
      populated: false,
    );

    final implementation = _buildApp(
      title: 'Implementation',
      icon: Icons.build_outlined,
      documentTitle: 'Implementation',
      populated: false,
    );

    _applications
      ..clear()
      ..addAll([docSpecs, codeSpecs, implementation]);
  }

  /// Builds one application with the common 4-region skeleton.
  ///
  /// When [populated] is false the middle Document split holds an empty
  /// editor and the side/bottom panels carry no tabs — the reused skeleton
  /// for CodeSpecs/Implementation until their content lands.
  ForgeApplication _buildApp({
    required String title,
    required IconData icon,
    required String documentTitle,
    required bool populated,
  }) {
    // Middle split 1: the document editor. Always present so the editor
    // region is never empty. DocSpecs uses the injected model-driven
    // [SpecDocumentEditor] when provided (§13); CodeSpecs/Implementation (and
    // pre-step-19 tests) fall back to an empty placeholder stub.
    final ForgeEditor docEditor = (populated && documentEditor != null)
        ? documentEditor!
        : PlaceholderEditor(
            title: documentTitle,
            icon: Icons.article_outlined,
            uri: Uri(
                scheme: 'specs',
                host: title.toLowerCase(),
                path: '/document'),
          );
    _editors.add(docEditor);
    final middlePanels = <MiddlePanelConfig>[
      MiddlePanelConfig(
        tabs: [MiddleTabConfig(editor: docEditor)],
      ),
    ];

    if (!populated) {
      // CodeSpecs / Implementation: skeleton with an empty document editor and
      // bare side/bottom panels (§5).
      return ForgeApplication(
        title: title,
        icon: icon,
        layout: ApplicationLayout(
          leftPanel: const PanelConfig(initialSize: 250),
          rightPanel: const PanelConfig(initialSize: 220),
          bottomPanel: const PanelConfig(initialSize: 180),
          middlePanels: middlePanels,
        ),
      );
    }

    // DocSpecs: the two further middle splits (Queue, Trail) plus all four
    // surrounding regions, each populated with a labelled placeholder.
    final queueEditor = PlaceholderEditor(
      title: 'Prompt Queue',
      icon: Icons.playlist_play_outlined,
      uri: Uri(scheme: 'specs', host: 'docspecs', path: '/queue'),
    );
    final trailEditor = PlaceholderEditor(
      title: 'Prompt Trail',
      icon: Icons.history_outlined,
      uri: Uri(scheme: 'specs', host: 'docspecs', path: '/trail'),
    );
    _editors..add(queueEditor)..add(trailEditor);
    middlePanels.add(
      MiddlePanelConfig(tabs: [MiddleTabConfig(editor: queueEditor)]),
    );
    middlePanels.add(
      MiddlePanelConfig(tabs: [MiddleTabConfig(editor: trailEditor)]),
    );

    // The §14 root navigator drives the document editor's active root (step
    // 20); falls back to a labelled placeholder in the pre-step-20 skeleton.
    final ForgeView navigator = navigatorView ??
        PlaceholderView(
          title: 'Navigator',
          icon: Icons.account_tree_outlined,
        );
    // The bottom "Chat" tab hosts the injected agent chat view (the connection
    // picker in step 11) when provided, falling back to a placeholder.
    final ForgeView chat = chatView ??
        PlaceholderView(
          title: 'Chat',
          icon: Icons.chat_bubble_outline,
        );
    final changeLog = PlaceholderView(
      title: 'Change Log',
      icon: Icons.rule_outlined,
    );
    _views..add(navigator)..add(chat)..add(changeLog);

    return ForgeApplication(
      title: title,
      icon: icon,
      layout: ApplicationLayout(
        leftPanel: PanelConfig(
          initialSize: 250,
          tabs: [
            PanelTabConfig(
              title: 'Navigator',
              icon: Icons.account_tree_outlined,
              sections: [navigator],
            ),
            if (structureView != null)
              PanelTabConfig(
                title: 'Structure',
                icon: Icons.account_tree,
                sections: [structureView!],
              ),
          ],
        ),
        rightPanel: PanelConfig(
          initialSize: 220,
          tabs: [
            PanelTabConfig(
              title: 'Change Log',
              icon: Icons.rule_outlined,
              sections: [changeLog],
            ),
          ],
        ),
        bottomPanel: PanelConfig(
          initialSize: 180,
          tabs: [
            PanelTabConfig(
              title: 'Chat',
              icon: Icons.chat_bubble_outline,
              sections: [chat],
            ),
          ],
        ),
        middlePanels: middlePanels,
      ),
    );
  }

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => _editors;

  @override
  List<ForgeView> get views => _views;

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeApplication> get applications => _applications;
}
