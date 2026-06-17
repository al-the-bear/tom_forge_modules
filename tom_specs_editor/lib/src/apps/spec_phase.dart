import 'package:flutter/foundation.dart';

/// One named artifact a TomSpecs creation phase produces or consumes — a
/// component of the phase, with the Phase-3 document(s) it derives from.
@immutable
class PhaseComponent {
  const PhaseComponent({
    required this.name,
    required this.description,
    this.source,
  });

  /// The component's display name (e.g. `UI Elements`).
  final String name;

  /// A one-line description of what the component is.
  final String description;

  /// The Phase-3 source document(s) it is generated from, if any
  /// (e.g. `UP (UI Prototype)`); null for derived/structural components.
  final String? source;
}

/// A TomSpecs creation phase, as defined in the quest's
/// `tom_system_creation.md`.
///
/// This is the **real content** the phase-2 *CodeSpecs* and *Implementation*
/// applications render (§20 step 25): the authoritative definition of what each
/// phase consumes, produces, and gates on. Phase 1 of the editor leaves these
/// two applications as empty skeletons (§1 non-goals); step 25 populates them
/// with their phase overviews so each app presents genuine methodology content
/// rather than a blank placeholder. The full model-driven CodeSpecs /
/// Implementation document editors (their own object models in `tom_specs_model`
/// / `tom_code_specs`) remain phase-2 follow-ups — see the quest's
/// `completion_steps.tom_specs.md`.
@immutable
class SpecPhase {
  const SpecPhase({
    required this.number,
    required this.title,
    required this.tagline,
    required this.purpose,
    required this.inputs,
    required this.produces,
    required this.components,
    required this.exitCriteria,
    required this.phase2Note,
  });

  /// The phase number in the 8-phase creation process (CodeSpecs = 4,
  /// Implementation = 6).
  final int number;

  /// The application/phase title (e.g. `CodeSpecs`).
  final String title;

  /// The one-line characterisation of the phase's key output.
  final String tagline;

  /// The phase purpose (a short prose paragraph).
  final String purpose;

  /// What must exist before the phase begins.
  final List<String> inputs;

  /// What the phase produces.
  final List<String> produces;

  /// The phase's named components (with their Phase-3 sources where relevant).
  final List<PhaseComponent> components;

  /// What must be true before proceeding to the next phase (the quality gate).
  final List<String> exitCriteria;

  /// A note on the phase's current editor status and phase-2 direction
  /// (e.g. the `tom_flutter_ui` component migration for the UI layers).
  final String phase2Note;

  /// **Phase 4 — CodeSpecs.** Transforms Phase-3 documentation into code-based
  /// artifacts: a skeletal application that *compiles but does not execute*.
  static const SpecPhase codeSpecs = SpecPhase(
    number: 4,
    title: 'CodeSpecs',
    tagline: 'Skeletal application — compiles but does not execute',
    purpose:
        'Transform the Phase 3 documentation into code-based artifacts that '
        'bridge the gap between specifications and implementation. At the end '
        'of this phase there is a skeletal application that compiles but does '
        'not execute — every method throws `UnimplementedError` pending the '
        'Implementation phase.',
    inputs: [
      'All Phase 3 documents (CS, RC, BP, BDM, AC, TR, UP, UC, BQP, SR, PPP, '
          'BSI)',
    ],
    produces: [
      'Skeletal application — compiles, throws `UnimplementedError` everywhere',
      'Complete CodeSpec annotations — every code element traces to its spec '
          'sources',
      'Traceability report — Phase 3 items mapped to code elements',
      'Gap analysis — Phase 3 requirements not yet mapped',
    ],
    components: [
      PhaseComponent(
        name: 'UI Elements',
        description: 'Flutter widgets and components for each screen.',
        source: 'UP (UI Prototype)',
      ),
      PhaseComponent(
        name: 'UI Data Model',
        description: 'View models and client-side state.',
        source: 'BDM (Business Data Model)',
      ),
      PhaseComponent(
        name: 'UI Layout',
        description: 'Layout separated from elements for manual override.',
        source: 'UP (UI Prototype)',
      ),
      PhaseComponent(
        name: 'UI Actions',
        description: 'User interactions wiring the client to the server.',
        source: 'BP (Business Process), UC (Use Cases)',
      ),
      PhaseComponent(
        name: 'Server Interface',
        description: 'API contracts and request/response types.',
        source: 'BP, AC (Authorization), UC',
      ),
      PhaseComponent(
        name: 'Server Endpoints & Business Logic',
        description: 'Dart server endpoints, business logic, and data access.',
        source: 'RC (Requirements), BP, TR (Technical Reqs)',
      ),
      PhaseComponent(
        name: 'Database Data Model',
        description: 'SQL schema: DDL and migrations.',
        source: 'BDM (Business Data Model)',
      ),
    ],
    exitCriteria: [
      'Application compiles without errors',
      'All Phase 3 requirements mapped to CodeSpec elements',
      'No gaps in traceability',
      'Ready for test derivation',
    ],
    phase2Note:
        'The Flutter client layers (UI Elements / Layout) target the '
        '`tom_flutter_ui` component library in phase 2. The in-document Dart '
        'editor embeds pre-generated analyzer summaries covering '
        '`tom_d4rt_flutter`, extended to `tom_flutter_ui` for these phase-2 '
        'code fields.',
  );

  /// **Phase 6 — Implementation.** Fills in the CodeSpec skeleton level by
  /// level, verifying each piece (with its Phase 5 tests) before proceeding.
  static const SpecPhase implementation = SpecPhase(
    number: 6,
    title: 'Implementation',
    tagline: 'Working code + unit tests',
    purpose:
        'Implement the system incrementally, verifying each piece before '
        'proceeding. Dependency analysis fixes the implementation order so '
        'each level builds only on already-verified levels below it.',
    inputs: [
      'CodeSpec elements (Phase 4)',
      'Derived tests (Phase 5)',
      'Dependency analysis',
    ],
    produces: [
      'Working code filling in the CodeSpec skeleton',
      'Passing unit tests for each implemented element',
      'Incremental, verified builds level by level',
    ],
    components: [
      PhaseComponent(
        name: 'Level 1 · Database Schema',
        description: 'No dependencies — implemented first.',
      ),
      PhaseComponent(
        name: 'Level 2 · Data Models',
        description: 'Depends on the schema.',
      ),
      PhaseComponent(
        name: 'Level 3 · Server Endpoints',
        description: 'Depends on the data models.',
      ),
      PhaseComponent(
        name: 'Level 4 · UI Data Models',
        description: 'Depends on the server interface.',
      ),
      PhaseComponent(
        name: 'Level 5 · UI Actions',
        description: 'Depends on the UI data models and server.',
      ),
      PhaseComponent(
        name: 'Level 6 · UI Elements & Layout',
        description: 'Depends on the UI actions.',
      ),
    ],
    exitCriteria: [
      'Each level implemented and verified before the next',
      'All Phase 5 derived tests pass',
      'No `UnimplementedError` left in the implemented levels',
    ],
    phase2Note:
        'The UI levels (5–6) are implemented against `tom_flutter_ui` '
        'components, replacing the phase-1 placeholder widgets.',
  );
}
