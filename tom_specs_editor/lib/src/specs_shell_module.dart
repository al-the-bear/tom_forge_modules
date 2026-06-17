import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'apps/phase_overview.dart';
import 'apps/spec_phase.dart';
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
/// **DocSpecs** is the phase-1 functional application: its four regions are
/// populated with the real document editor, structure browser, navigator and
/// chat suite (steps 10–22). **CodeSpecs** and **Implementation** are the
/// phase-2 applications; step 25 populates them with their **phase overviews**
/// ([SpecPhase.codeSpecs] / [SpecPhase.implementation]) — the document region
/// renders a [PhaseOverviewEditor] and the left panel a [PhaseOutlineView], so
/// each app presents the real TomSpecs methodology content for its phase rather
/// than an empty placeholder. Their full model-driven document editors (their
/// own object models) remain phase-2 follow-ups.
class SpecsShellModule extends ForgeModule {
  SpecsShellModule({
    this.structureView,
    this.chatView,
    this.documentEditor,
    this.queueEditor,
    this.trailEditor,
    this.navigatorView,
  });

  /// The model-driven document editor (§13), hosted as the DocSpecs middle
  /// "Document" split when provided. Null in the skeleton tests that predate
  /// step 19, where the split falls back to a [PlaceholderEditor].
  final ForgeEditor? documentEditor;

  /// The prompt-queue editor (from [AgentChatModule]), hosted as the DocSpecs
  /// middle "Prompt Queue" split (§5 Col 2) when provided. Null in the skeleton
  /// tests that predate the chat suite, where the split falls back to a
  /// [PlaceholderEditor].
  final ForgeEditor? queueEditor;

  /// The prompt-trail editor (from [AgentChatModule]), hosted as the DocSpecs
  /// middle "Prompt Trail" split (§5 Col 3) when provided. Null in the skeleton
  /// tests that predate the chat suite, where the split falls back to a
  /// [PlaceholderEditor].
  final ForgeEditor? trailEditor;

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
      phase: SpecPhase.codeSpecs,
    );

    final implementation = _buildApp(
      title: 'Implementation',
      icon: Icons.build_outlined,
      documentTitle: 'Implementation',
      populated: false,
      phase: SpecPhase.implementation,
    );

    _applications
      ..clear()
      ..addAll([docSpecs, codeSpecs, implementation]);
  }

  /// Builds one application with the common 4-region skeleton.
  ///
  /// DocSpecs ([populated] = true) hosts the injected model-driven editors and
  /// all four populated regions. The phase-2 apps ([populated] = false, with a
  /// [phase]) host their [PhaseOverviewEditor] in the document region and a
  /// [PhaseOutlineView] in the left panel (step 25), so their content is real
  /// rather than a blank placeholder.
  ForgeApplication _buildApp({
    required String title,
    required IconData icon,
    required String documentTitle,
    required bool populated,
    SpecPhase? phase,
  }) {
    // Middle split 1: the document editor. Always present so the editor
    // region is never empty. DocSpecs uses the injected model-driven
    // [SpecDocumentEditor] when provided (§13); the phase-2 apps render their
    // [PhaseOverviewEditor]; bare pre-step-19/25 skeleton tests fall back to a
    // placeholder stub.
    final ForgeEditor docEditor = (populated && documentEditor != null)
        ? documentEditor!
        : (phase != null)
            ? PhaseOverviewEditor(phase: phase)
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
      // CodeSpecs / Implementation: the phase overview in the document region
      // plus an "Overview" left-panel tab listing the phase components (§5,
      // step 25). The right/bottom regions stay bare — their chat/change-log
      // surfaces are wired only for the functional DocSpecs app.
      final List<PanelTabConfig> leftTabs = [];
      if (phase != null) {
        final outline = PhaseOutlineView(phase: phase);
        _views.add(outline);
        leftTabs.add(PanelTabConfig(
          title: 'Overview',
          icon: Icons.list_alt_outlined,
          sections: [outline],
        ));
      }
      return ForgeApplication(
        title: title,
        icon: icon,
        layout: ApplicationLayout(
          leftPanel: PanelConfig(initialSize: 250, tabs: leftTabs),
          rightPanel: const PanelConfig(initialSize: 220),
          bottomPanel: const PanelConfig(initialSize: 180),
          middlePanels: middlePanels,
        ),
      );
    }

    // DocSpecs: the two further middle splits (Queue = Col 2, Trail = Col 3)
    // plus all four surrounding regions. The queue/trail editors come from the
    // injected [AgentChatModule] (the real §11.2/§11.3 columns); the skeleton
    // tests that predate the chat suite fall back to labelled placeholders.
    final ForgeEditor queueSplit = queueEditor ??
        PlaceholderEditor(
          title: 'Prompt Queue',
          icon: Icons.playlist_play_outlined,
          uri: Uri(scheme: 'specs', host: 'docspecs', path: '/queue'),
        );
    final ForgeEditor trailSplit = trailEditor ??
        PlaceholderEditor(
          title: 'Prompt Trail',
          icon: Icons.history_outlined,
          uri: Uri(scheme: 'specs', host: 'docspecs', path: '/trail'),
        );
    _editors..add(queueSplit)..add(trailSplit);
    middlePanels.add(
      MiddlePanelConfig(tabs: [MiddleTabConfig(editor: queueSplit)]),
    );
    middlePanels.add(
      MiddlePanelConfig(tabs: [MiddleTabConfig(editor: trailSplit)]),
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
