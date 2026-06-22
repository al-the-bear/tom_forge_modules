/// The sparse, path-keyed in-memory document representation.
///
/// This file is now a thin re-export shim: the implementation lives in the
/// generic `tom_som_dart_runtime` package (step 3 of the multi-platform
/// spec-model plan), so the editor and every generated typed facade share one
/// runtime. Existing `import '.../document/spec_document.dart'` sites keep
/// resolving unchanged.
library;

export 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show SpecDocument, SpecDocumentState;
