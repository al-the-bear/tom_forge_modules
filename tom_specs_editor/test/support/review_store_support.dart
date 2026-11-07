import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';

/// A review store over an in-memory workspace, for a test that needs a store
/// but no disk: its file is `review/structure_review.yaml` of [fileSystem]
/// (a fresh one unless given).
ReviewStore memoryReviewStore([TomMemoryFileSystem? fileSystem]) =>
    ReviewStore.resolveDefault(fileSystem ?? TomMemoryFileSystem());
