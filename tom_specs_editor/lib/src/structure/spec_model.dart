/// In-memory representation of the exported TomSpecs class graph
/// (`assets/spec_model.json`, produced by `tom_specs_clitool/bin/model_json.dart`).
///
/// This file is now a thin re-export shim: the meta-model implementation lives
/// in the generic `tom_som_dart_runtime` package (step 3 of the multi-platform
/// spec-model plan). Existing `import '.../structure/spec_model.dart'` sites
/// keep resolving unchanged; the new `SpecAnnotation` surface comes along for
/// free.
///
/// The shim also re-exports the *display semantics* the runtime defines — which
/// markers a row carries, what each says, and the structural-path segments they
/// are keyed by. Those are shared with `tom_specs_reviewer` deliberately: the
/// two surfaces render the same class graph and must not disagree about what an
/// annotation means, even though each paints it in its own theme.
library;

export 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show
        KindLink,
        NoArtifactLink,
        OneOfGroup,
        SpecAnnotation,
        SpecChip,
        SpecChipRole,
        SpecClass,
        SpecField,
        SpecFieldKind,
        SpecModel,
        SpecRoot,
        SpecRowExtras,
        StandardReferences,
        FormFieldSpec,
        SpecValidationCode,
        SpecValidationError,
        caseChips,
        codeSpecKindChips,
        fieldChips,
        followUpKindChips,
        kindChips,
        noArtifactChips,
        oneOfChips,
        projectionChip,
        referencesChip,
        unusedChip,
        kListItemSegment,
        kOneOfSegment,
        kProjectionExplanation,
        kProjectionLabel,
        kReferencesChipLabel,
        kRenderedAnnotations,
        kSectionContentSegment,
        kSerializationOrderToggleLabel,
        kUnusedChipLabel;
