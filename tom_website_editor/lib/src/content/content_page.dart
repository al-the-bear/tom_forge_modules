/// Whether a page region is generator-managed (read-only) or a hand-owned
/// override (editable) — §6a override/managed insert-marker regions.
enum ContentRegionKind { managed, editable }

/// Decides a marker line's region kind, or `null` when the line is not a marker.
///
/// The default ([defaultPageMarker]) keys off the `@tom:override` /
/// `@tom:managed` insert markers named in §6a. The exact marker grammar lives in
/// the website's spec (enterprise §6.2) and is reconciled in the §9.7 e2e step;
/// the predicate is injectable so the precise form can be supplied without
/// touching the region model.
typedef PageMarkerClassifier = ContentRegionKind? Function(String line);

/// Default marker classifier: a line mentioning `@tom:override` opens an
/// editable region, `@tom:managed` opens a managed region.
ContentRegionKind? defaultPageMarker(String line) {
  if (line.contains('@tom:override')) return ContentRegionKind.editable;
  if (line.contains('@tom:managed')) return ContentRegionKind.managed;
  return null;
}

/// A contiguous run of page lines belonging to one region. The marker line, when
/// present, is the first of [lines]; the leading preamble before any marker has
/// no marker.
class ContentPageRegion {
  const ContentPageRegion({
    required this.kind,
    required this.hasMarker,
    required this.lines,
  });

  /// managed (read-only) or editable (override).
  final ContentRegionKind kind;

  /// `true` when [lines] begins with the region's marker line.
  final bool hasMarker;

  /// The region's source lines, marker first when [hasMarker].
  final List<String> lines;

  /// The marker line, or `null` for a marker-less preamble.
  String? get marker => hasMarker ? lines.first : null;

  /// The editable body (everything after the marker line).
  String get body => (hasMarker ? lines.skip(1) : lines).join('\n');
}

/// A standalone page (`content/pages/*.md`) split into managed/override regions
/// (§6a). [serialize] reproduces the source exactly, so generated (managed)
/// regions and the markers themselves are never disturbed when an override
/// region is edited.
class ContentPage {
  const ContentPage(this.regions);

  /// The page regions, in document order.
  final List<ContentPageRegion> regions;

  /// Parses [raw] into regions using [classify] (defaults to
  /// [defaultPageMarker]).
  factory ContentPage.parse(String raw,
      {PageMarkerClassifier classify = defaultPageMarker}) {
    final lines = raw.split('\n');
    final regions = <ContentPageRegion>[];
    var kind = ContentRegionKind.managed;
    var hasMarker = false;
    var buffer = <String>[];

    void flush() {
      if (buffer.isEmpty && regions.isNotEmpty && !hasMarker) return;
      regions.add(ContentPageRegion(
          kind: kind, hasMarker: hasMarker, lines: List.of(buffer)));
    }

    for (final line in lines) {
      final markerKind = classify(line);
      if (markerKind != null) {
        flush();
        kind = markerKind;
        hasMarker = true;
        buffer = [line];
      } else {
        buffer.add(line);
      }
    }
    flush();
    return ContentPage(regions);
  }

  /// The editable (override) regions, in document order.
  Iterable<ContentPageRegion> get editableRegions =>
      regions.where((r) => r.kind == ContentRegionKind.editable);

  /// Re-joins every region's lines back into the source text (round-trip).
  String serialize() => regions.expand((r) => r.lines).join('\n');

  /// Returns a copy with region [index]'s body replaced by [newBody]; the
  /// region's marker line (if any) and all other regions are preserved verbatim.
  ContentPage withRegionBody(int index, String newBody) {
    final region = regions[index];
    final newLines = <String>[
      if (region.hasMarker) region.lines.first,
      ...newBody.split('\n'),
    ];
    final updated = List.of(regions);
    updated[index] = ContentPageRegion(
        kind: region.kind, hasMarker: region.hasMarker, lines: newLines);
    return ContentPage(updated);
  }
}
