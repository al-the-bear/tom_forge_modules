/// In-memory representation of the exported TomSpecs class graph
/// (`assets/spec_model.json`, produced by `tom_specs_clitool/bin/model_json.dart`).
///
/// This file is now a thin re-export shim: the meta-model implementation lives
/// in the generic `tom_som_dart_runtime` package (step 3 of the multi-platform
/// spec-model plan). Existing `import '.../structure/spec_model.dart'` sites
/// keep resolving unchanged; the new `SpecAnnotation` surface comes along for
/// free.
library;

export 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show
        SpecAnnotation,
        SpecClass,
        SpecField,
        SpecFieldKind,
        SpecModel,
        SpecRoot,
        FormFieldSpec;
