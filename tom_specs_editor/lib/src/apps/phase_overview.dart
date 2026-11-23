import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../document/spec_markdown.dart';
import 'spec_phase.dart';

/// The middle "document" region for a phase-2 application (CodeSpecs /
/// Implementation): a read-only overview of the [SpecPhase] — its purpose,
/// inputs, produced artifacts, components, and exit criteria — rendered through
/// the same [SpecMarkdown] seam the DocSpecs document editor uses.
///
/// This is the **real content** `tom_specs_editor_specification.md` §20 step 25
/// requires the two phase-2 apps to render, in place of the empty placeholder
/// editor those apps carried in phase
/// 1. The full model-driven CodeSpecs / Implementation document editors (their
/// own object models) are phase-2 follow-ups tracked in the quest's
/// `deferred.tom_specs.md`.
class PhaseOverviewEditor extends ForgeSurfaceEditor {
  PhaseOverviewEditor({required this.phase})
    : _title = ValueNotifier<String>(phase.title),
      _titleExtension = ValueNotifier<String?>('Phase ${phase.number}'),
      uri = Uri(
        scheme: 'specs',
        host: phase.title.toLowerCase(),
        path: '/overview',
      );

  /// The phase whose overview this editor renders.
  final SpecPhase phase;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;

  @override
  IconData get icon => Icons.article_outlined;

  @override
  final Uri uri;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  Widget buildMain(BuildContext context) => PhaseOverviewBody(phase: phase);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// The left-panel "Overview" tab for a phase-2 application: a compact outline of
/// the phase's components, so the app's side region also presents real content.
class PhaseOutlineView extends ForgeView {
  PhaseOutlineView({required this.phase})
    : _title = ValueNotifier<String>('Overview'),
      _titleExtension = ValueNotifier<String?>(null);

  /// The phase whose components this outline lists.
  final SpecPhase phase;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;

  @override
  IconData get icon => Icons.list_alt_outlined;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        SpecMarkdown('## ${phase.title}'),
        SpecMarkdown('Phase ${phase.number} · ${phase.tagline}', muted: true),
        const SizedBox(height: 8),
        for (final c in phase.components)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.chevron_right, size: 18),
            title: Text(c.name, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              c.source == null
                  ? c.description
                  : '${c.description}  ·  from ${c.source}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// The scrollable body of [PhaseOverviewEditor].
class PhaseOverviewBody extends StatelessWidget {
  const PhaseOverviewBody({super.key, required this.phase});

  final SpecPhase phase;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SpecMarkdown('# ${phase.title} — Phase ${phase.number}'),
        SpecMarkdown('*${phase.tagline}*', muted: true),
        const SizedBox(height: 12),
        SpecMarkdown(phase.purpose),
        _Section(title: 'Inputs', items: phase.inputs),
        _Section(title: 'Produces', items: phase.produces),
        _ComponentSection(components: phase.components),
        _Section(title: 'Exit criteria', items: phase.exitCriteria),
        const SizedBox(height: 12),
        _Phase2Note(text: phase.phase2Note),
      ],
    );
  }
}

/// A titled bullet list (Inputs / Produces / Exit criteria).
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpecMarkdown('## $title'),
          for (final item in items) SpecMarkdown('- $item'),
        ],
      ),
    );
  }
}

/// The Components section: each component with its description and Phase-3
/// source rendered as a labelled block.
class _ComponentSection extends StatelessWidget {
  const _ComponentSection({required this.components});

  final List<PhaseComponent> components;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SpecMarkdown('## Components'),
          for (final c in components)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SpecMarkdown(
                c.source == null
                    ? '- **${c.name}** — ${c.description}'
                    : '- **${c.name}** — ${c.description} *(from ${c.source})*',
              ),
            ),
        ],
      ),
    );
  }
}

/// The phase-2 status / direction note, set off in a tinted card.
class _Phase2Note extends StatelessWidget {
  const _Phase2Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.science_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: SpecMarkdown('Phase 2 — $text', muted: true)),
          ],
        ),
      ),
    );
  }
}
