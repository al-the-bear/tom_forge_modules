/// The TomSpecs editor as a library for other Forge apps: the spec document
/// editor over one `*.docspecs.yaml` / `*.tomspecs.yaml` file of a shell
/// ([SpecFileEditor], [isTomSpecsFile]) and the spec model it needs
/// ([loadSpecModelFromAsset] with [specModelPackageAssetKey]).
library;

export 'src/document/spec_file_editor.dart';
export 'src/structure/spec_model.dart' show SpecModel;
export 'src/structure/spec_structure_view.dart'
    show loadSpecModelFromAsset, specModelAssetKey, specModelPackageAssetKey;
