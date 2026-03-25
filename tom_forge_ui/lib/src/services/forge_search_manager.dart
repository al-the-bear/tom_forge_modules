import 'package:tom_forge_core/tom_forge_core.dart';

/// A search result for a single file.
class ForgeSearchResult {
  final Uri uri;
  final List<ForgeSearchMatch> matches;

  const ForgeSearchResult({required this.uri, required this.matches});
}

/// A single match within a file.
class ForgeSearchMatch {
  final ForgeTextRange range;
  final String lineText;

  const ForgeSearchMatch({required this.range, required this.lineText});
}

/// Programmatic workspace-wide text search.
abstract class ForgeSearchManager {
  Future<List<ForgeSearchResult>> search(
    String query, {
    bool isRegExp = false,
    bool isCaseSensitive = false,
    bool isWordMatch = false,
    String? includePattern,
    String? excludePattern,
    int? maxResults,
  });

  Stream<ForgeSearchResult> searchStream(
    String query, {
    bool isRegExp = false,
    bool isCaseSensitive = false,
    bool isWordMatch = false,
    String? includePattern,
    String? excludePattern,
  });
}
