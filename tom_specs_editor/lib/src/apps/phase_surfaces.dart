import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'spec_phase.dart';

/// The four agent-driven surfaces a TomSpecs application surrounds its document
/// region with (`tom_specs_editor_specification.md` §5): the chat suite, the
/// change log, the prompt queue, and the prompt trail.
///
/// On **DocSpecs** these are the *live* injected instances (the real agent chat
/// view, the queue/trail editors, the change log) — they drive and reflect the
/// agent's edits to the live DocSpecs document. The **CodeSpecs** and
/// **Implementation** phase-2 apps do not yet own a live model-driven document
/// controller (that is OE-24a — routing each app from the read-only
/// `PhaseOverviewEditor` to a `SpecDocumentEditor`; CodeSpecs is code only, so
/// there is no `tom_code_specs` document to merge — the link is the DocSpecs ↔
/// CodeSpecs annotations of `codespecs_mapping.md` §9). Hosting the *shared*
/// DocSpecs instances here would let the agent mutate the DocSpecs document
/// while the user is "in" CodeSpecs/Implementation — semantically wrong and
/// worse than an honest, labelled surface. So until OE-24a lands the phase-2
/// apps present these four regions as [PhaseSurfaceView]/[PhaseSurfaceEditor]
/// placeholders that name the surface and state when it activates, keeping the
/// 4-region layout consistent across all three applications (OE-26).
enum PhaseSurface {
  chat('Chat', Icons.chat_bubble_outline),
  changeLog('Change Log', Icons.rule_outlined),
  queue('Prompt Queue', Icons.playlist_play_outlined),
  trail('Prompt Trail', Icons.history_outlined);

  const PhaseSurface(this.label, this.icon);

  /// The region's display title (also the panel tab title).
  final String label;

  /// The region's icon.
  final IconData icon;

  /// The slug used in a phase-scoped editor [Uri] path (e.g. `queue`).
  String get slug => name;
}

/// The shared body for a phase-2 [PhaseSurface] region: the surface's icon and
/// name plus a caption explaining that it activates once the phase gains its own
/// model-driven document editor (OE-24a). Truthful where a bare placeholder
/// would imply the surface is simply unbuilt.
class PhaseSurfaceBody extends StatelessWidget {
  const PhaseSurfaceBody({super.key, required this.phase, required this.surface});

  final SpecPhase phase;
  final PhaseSurface surface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(surface.icon, size: 28, color: theme.disabledColor),
            const SizedBox(height: 8),
            Text(
              surface.label,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.disabledColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Activates with the ${phase.title} document editor (phase 2)',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.disabledColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// A phase-2 surface hosted as a side/bottom panel tab (Chat, Change Log).
class PhaseSurfaceView extends ForgeView {
  PhaseSurfaceView({required this.phase, required this.surface})
      : _title = ValueNotifier<String>(surface.label),
        _titleExtension = ValueNotifier<String?>(null);

  final SpecPhase phase;
  final PhaseSurface surface;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;

  @override
  IconData get icon => surface.icon;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) =>
      PhaseSurfaceBody(phase: phase, surface: surface);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// A phase-2 surface hosted as a middle (editor) split (Prompt Queue, Trail).
///
/// Declines every real file ([canHandle] → reject) so the shell never routes an
/// opened document into a phase-2 placeholder split; it exists only so the
/// phase-2 middle area carries the same three columns as DocSpecs.
class PhaseSurfaceEditor extends ForgeEditor {
  PhaseSurfaceEditor({required this.phase, required this.surface})
      : _title = ValueNotifier<String>(surface.label),
        _titleExtension = ValueNotifier<String?>(null),
        uri = Uri(
          scheme: 'specs',
          host: phase.title.toLowerCase(),
          path: '/${surface.slug}',
        );

  final SpecPhase phase;
  final PhaseSurface surface;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;
  final ValueNotifier<bool> _isDirty = ValueNotifier<bool>(false);

  @override
  IconData get icon => surface.icon;

  @override
  final Uri uri;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  void markClean() => _isDirty.value = false;

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  Widget buildMain(BuildContext context) =>
      PhaseSurfaceBody(phase: phase, surface: surface);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}
