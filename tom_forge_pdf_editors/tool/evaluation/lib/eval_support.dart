// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// What every measure of the harness shares: the run's configuration, YAML
/// output, process memory, frame statistics, the PDFKit tool (macOS
/// Preview's renderer) and the pixel comparison.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// The run's settings, given by `run_evaluation.sh` as `--dart-define`s.
abstract final class EvalConfig {
  /// The sample files (`samples/files/` of the idea's folder).
  static const samples = String.fromEnvironment('EVAL_SAMPLES');

  /// `evaluation/results/` of the idea's folder.
  static const results = String.fromEnvironment('EVAL_RESULTS');

  /// A scratch folder for this run (copies, page images).
  static const work = String.fromEnvironment('EVAL_WORK');

  /// The compiled PDFKit tool (`pdfkit_tool.swift`).
  static const pdfkit = String.fromEnvironment('EVAL_PDFKIT');

  /// This run's number, 1–3.
  static const run = int.fromEnvironment('EVAL_RUN', defaultValue: 1);

  /// The Forge commit, the Flutter version (from the runner).
  static const forgeCommit = String.fromEnvironment('EVAL_FORGE_COMMIT');
  static const flutterVersion = String.fromEnvironment('EVAL_FLUTTER');

  /// Write page images of major differences into the results (run 1).
  static bool get screenshots => run == 1;

  static String sample(String name) => '$samples/$name';

  /// [name] copied into this run's scratch folder under [as].
  static String copy(String name, String as) {
    final target = '$work/$as';
    File(sample(name)).copySync(target);
    return target;
  }
}

/// The password of `pdf-encrypted` (samples.yaml).
const evalEncryptedPassword = 'ELXRTQWS';

/// The pages compared for rendering fidelity, 0-based, per sample.
const evalFidelityPages = <String, List<int>>{
  'pdf-text.pdf': [0, 1, 2, 3, 4],
  'pdf-annot.pdf': [0, 1],
  'pdf-form.pdf': [0],
  'pdf-scan.pdf': [0, 1],
  'pdf-encrypted.pdf': [0],
  'pdf-long.pdf': [0, 2000],
};

/// Pixels per point of the fidelity renders (108 dpi).
const evalFidelityScale = 1.5;

/// The search term per sample of the whole-document search.
const evalSearchTerms = <String, String>{
  'pdf-text.pdf': 'reasoning',
  'pdf-long.pdf': 'depreciation',
};

// ---------------------------------------------------------------- results

/// Writes [value] (maps, lists, strings, numbers, booleans, null) as YAML.
String toYaml(Object? value, [int indent = 0]) {
  final b = StringBuffer();
  _yaml(b, value, indent, topLevel: true);
  return b.toString();
}

String _scalar(Object? v) {
  if (v == null) return 'null';
  if (v is bool || v is int) return '$v';
  if (v is double) return v.isFinite ? v.toStringAsFixed(3) : '.nan';
  final s = '$v';
  final plain =
      RegExp(r'^[A-Za-z0-9_./ ()%+-]*$').hasMatch(s) &&
      s.isNotEmpty &&
      !s.startsWith(' ') &&
      !s.endsWith(' ') &&
      !RegExp(
        r'^(true|false|null|yes|no|on|off|[0-9.+-]+)$',
        caseSensitive: false,
      ).hasMatch(s);
  return plain ? s : jsonEncode(s);
}

void _yaml(StringBuffer b, Object? v, int indent, {bool topLevel = false}) {
  final pad = ' ' * indent;
  if (v is Map) {
    if (v.isEmpty) {
      b.writeln(topLevel ? '{}' : ' {}');
      return;
    }
    if (!topLevel) b.writeln();
    for (final e in v.entries) {
      final child = e.value;
      if (child is Map && child.isNotEmpty ||
          child is List && child.isNotEmpty) {
        b.write('$pad${_scalar(e.key)}:');
        _yaml(b, child, indent + 2);
      } else {
        b.write('$pad${_scalar(e.key)}:');
        if (child is Map) {
          b.writeln(' {}');
        } else if (child is List) {
          b.writeln(' []');
        } else {
          b.writeln(' ${_scalar(child)}');
        }
      }
    }
  } else if (v is List) {
    if (v.isEmpty) {
      b.writeln(' []');
      return;
    }
    b.writeln();
    for (final item in v) {
      if (item is Map && item.isNotEmpty) {
        // The first key on the dash line, the rest below it.
        final lines = toYaml(item, 0).trimRight().split('\n');
        b.writeln('$pad- ${lines.first}');
        for (final line in lines.skip(1)) {
          b.writeln('$pad  $line');
        }
      } else if (item is List) {
        b.write('$pad-');
        _yaml(b, item, indent + 2);
      } else {
        b.writeln('$pad- ${_scalar(item)}');
      }
    }
  } else {
    b.writeln(_scalar(v));
  }
}

/// Writes [results] to `results/<route>/run-<n>.yaml`.
void writeResults(String route, Map<String, Object?> results) {
  final dir = Directory('${EvalConfig.results}/$route')
    ..createSync(recursive: true);
  final file = File('${dir.path}/run-${EvalConfig.run}.yaml');
  file.writeAsStringSync(
    '# The $route route, run ${EvalConfig.run} of the PDF evaluation '
    '(officeproto23).\n# Written by tom_forge_pdf_editors/tool/evaluation; '
    'part-evaluation of the working document.\n${toYaml(results)}',
  );
  // A JSON copy for run_evaluation.py's summary (the scratch folder only).
  File(
    '${EvalConfig.work}/$route-run-${EvalConfig.run}.json',
  ).writeAsStringSync(jsonEncode(_jsonSafe(results)));
  print('[eval] wrote ${file.path}');
}

/// [v] with non-finite numbers as null and other values as strings.
Object? _jsonSafe(Object? v) => switch (v) {
  null || bool() || int() || String() => v,
  double() => v.isFinite ? v : null,
  Map() => {for (final e in v.entries) '${e.key}': _jsonSafe(e.value)},
  List() => [for (final x in v) _jsonSafe(x)],
  _ => '$v',
};

/// A measure that could not be taken, with why.
Map<String, Object?> notMeasured(String reason) => {
  'measured': false,
  'reason': reason,
};

// ---------------------------------------------------------- the machine

/// The machine, macOS and the versions every run records.
Map<String, Object?> environmentInfo({
  Map<String, Object?> engines = const {},
}) {
  String run(String exe, List<String> args) {
    try {
      return '${Process.runSync(exe, args).stdout}'.trim();
    } catch (_) {
      return '?';
    }
  }

  return {
    'host': run('hostname', ['-s']),
    'cpu': run('sysctl', ['-n', 'machdep.cpu.brand_string']),
    'memory_gb':
        (int.tryParse(run('sysctl', ['-n', 'hw.memsize'])) ?? 0) ~/ (1 << 30),
    'macos':
        '${run('sw_vers', ['-productVersion'])} '
        '(${run('sw_vers', ['-buildVersion'])})',
    'build_mode': const bool.fromEnvironment('dart.vm.product')
        ? 'release'
        : const bool.fromEnvironment('dart.vm.profile')
        ? 'profile'
        : 'debug',
    'flutter': EvalConfig.flutterVersion,
    'forge_commit': EvalConfig.forgeCommit,
    'run': EvalConfig.run,
    'started': DateTime.now().toIso8601String(),
    // A locked screen hides every window: WebKit then draws only because
    // the evaluation app turns its occlusion detection off, and frame
    // timings are not those of a person watching.
    'screen_locked': screenLocked,
    ...engines,
  };
}

/// Whether the screen was locked when the run started (asked once): every
/// window is then hidden, WebKit gives its pages no animation frames, and
/// frame timings are not those of a person watching.
final bool screenLocked = () {
  try {
    final r = Process.runSync('swift', [
      '-e',
      'import CoreGraphics; let d = CGSessionCopyCurrentDictionary() as? '
          '[String: Any] ?? [:]; print((d["CGSSessionScreenIsLocked"] as? '
          'Int ?? 0) == 1)',
    ]);
    return '${r.stdout}'.trim() == 'true';
  } catch (_) {
    return false;
  }
}();

/// The reason a frame-timing measure is not taken on a locked screen.
const lockedScreenReason =
    'the screen was locked during this run: macOS hides every window, so '
    'WebKit gives the page no animation frames and Flutter\'s frames are not '
    'those of a person watching; repeated with the screen unlocked by the '
    'todo the evaluation files for it';

// ---------------------------------------------------------------- memory

/// The physical footprint of process [pid] in MB (what Activity Monitor
/// shows as Memory), from `footprint`; null when it cannot be read.
double? footprintMb(int pid) {
  final r = Process.runSync('footprint', ['-p', '$pid']);
  final m = RegExp(
    r'Footprint:\s*([\d.]+)\s*(KB|MB|GB)',
  ).firstMatch('${r.stdout}');
  if (m == null) return null;
  final v = double.parse(m.group(1)!);
  return switch (m.group(2)) {
    'KB' => v / 1024,
    'GB' => v * 1024,
    _ => v,
  };
}

/// The resident set of process [pid] in MB, from `ps`.
double? residentMb(int pid) {
  final r = Process.runSync('ps', ['-o', 'rss=', '-p', '$pid']);
  final kb = int.tryParse('${r.stdout}'.trim());
  return kb == null ? null : kb / 1024;
}

/// The pids of every WebKit content process now running.
Set<int> webContentPids() {
  final r = Process.runSync('ps', ['-axo', 'pid=,comm=']);
  return {
    for (final line in LineSplitter.split('${r.stdout}'))
      if (line.contains('com.apple.WebKit.WebContent'))
        int.parse(line.trim().split(RegExp(r'\s+')).first),
  };
}

/// This process's memory, and with [webContent] the content processes too.
Map<String, Object?> memorySample({Set<int> webContent = const {}}) {
  final app = footprintMb(pid);
  final content = <String, Object?>{
    for (final p in webContent) '$p': ?footprintMb(p),
  };
  final contentSum = content.values.fold<double>(
    0,
    (a, b) => a + (b! as double),
  );
  return {
    'app_footprint_mb': app,
    'app_resident_mb': residentMb(pid),
    if (webContent.isNotEmpty) ...{
      'webcontent_footprint_mb': content,
      'total_footprint_mb': (app ?? 0) + contentSum,
    },
  };
}

// ------------------------------------------------------------ statistics

double _percentile(List<num> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  final i = ((sorted.length - 1) * p).round();
  return sorted[i].toDouble();
}

/// Median and p95 of [values].
Map<String, Object?> distribution(List<num> values) {
  final s = [...values]..sort();
  return {
    'count': s.length,
    'median': _percentile(s, 0.5),
    'p95': _percentile(s, 0.95),
    'max': s.isEmpty ? double.nan : s.last.toDouble(),
  };
}

/// Frame statistics: build and raster times in ms per frame, and the share
/// of frames over the 16.7 ms budget (jank).
Map<String, Object?> frameStats(List<ui.FrameTiming> timings) {
  double ms(Duration d) => d.inMicroseconds / 1000;
  final build = [for (final t in timings) ms(t.buildDuration)];
  final raster = [for (final t in timings) ms(t.rasterDuration)];
  final over = timings
      .where((t) => ms(t.buildDuration) > 16.7 || ms(t.rasterDuration) > 16.7)
      .length;
  return {
    'frames': timings.length,
    'build_ms': distribution(build),
    'raster_ms': distribution(raster),
    'jank_share': timings.isEmpty ? double.nan : over / timings.length,
  };
}

/// A page frame is late (jank) when its interval is over this many ms: one
/// and a half frame budgets at 60 Hz, so at least one frame was missed.
/// WebKit coarsens `performance.now()` to whole milliseconds, so an on-time
/// frame of 16.67 ms reads as 16 or 17 ms; the 16.7 ms budget itself would
/// count half of the on-time frames as late.
const kPageJankThresholdMs = 25.0;

/// Frame intervals measured in a page with `requestAnimationFrame`, in ms:
/// the share over [kPageJankThresholdMs] is the jank.
Map<String, Object?> intervalStats(List<num> intervals) {
  final over = intervals.where((i) => i > kPageJankThresholdMs).length;
  return {
    'frames': intervals.length,
    'interval_ms': distribution(intervals),
    'jank_threshold_ms': kPageJankThresholdMs,
    'jank_share': intervals.isEmpty ? double.nan : over / intervals.length,
  };
}

// ------------------------------------------------------------- PDFKit

/// Runs the PDFKit tool; its stdout lines.
List<String> pdfKit(List<String> args) {
  final r = Process.runSync(EvalConfig.pdfkit, args);
  if (r.exitCode != 0) {
    throw StateError('pdfkit_tool ${args.first}: ${r.stderr}');
  }
  return LineSplitter.split(
    '${r.stdout}',
  ).where((l) => l.trim().isNotEmpty && !l.startsWith('CoreGraphics')).toList();
}

/// Whether PDFKit opens [path] (with [password]): `ok <pages> <locked>`.
String pdfKitOpens(String path, {String? password}) =>
    pdfKit(['opens', path, ?password]).join(' ');

/// The annotation types PDFKit reads in [path], as `page:Type`.
List<String> pdfKitAnnotations(String path, {String? password}) => [
  for (final line in pdfKit(['annots', path, ?password]))
    if (line.contains('\t')) line.replaceFirst('\t', ':'),
];

/// The form values PDFKit reads on page 0 of [path].
List<String> pdfKitFields(String path) => pdfKit(['fields', path]);

/// PDFKit's (Preview's) rendering of [page] of [path] at [w] × [h] pixels.
void pdfKitRender(
  String path,
  int page,
  int w,
  int h,
  String out, {
  String? password,
}) => pdfKit(['render', path, '$page', '$w', '$h', out, ?password]);

/// The pixel difference of [a] and [b] (b drawn at a's size): [ratio] the
/// share of pixels that differ by more than 40 of 255 in a channel and have
/// no match within one pixel in the other image (both ways), [raw] the same
/// without that tolerance, [mean] the mean absolute difference. [marked]
/// gets an image with the differences red and one-pixel shifts orange.
({double ratio, double raw, double mean}) pixelDiff(
  String a,
  String b, {
  String? marked,
}) {
  final out = pdfKit(['diff', a, b, ?marked]).single.split(' ');
  return (
    ratio: double.parse(out[0]),
    mean: double.parse(out[1]),
    raw: double.parse(out[4]),
  );
}

/// The automatic verdict of a page comparison (the human one follows in the
/// report): identical below 0.5 % of differing pixels, minor below 5 %,
/// major above.
String verdictOf(double ratio) => ratio < 0.005
    ? 'identical'
    : ratio < 0.05
    ? 'minor'
    : 'major';

/// The worse of two verdicts.
String worse(String a, String b) {
  const order = ['identical', 'minor', 'major', 'fails to open'];
  return order.indexOf(a) >= order.indexOf(b) ? a : b;
}

// ------------------------------------------------------------- images

/// BGRA pixels as a PNG.
Future<Uint8List> bgraToPng(Uint8List bgra, int w, int h) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bgra);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.bgra8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return png!.buffer.asUint8List();
}

/// Bytes on disk of [path] (a file or a folder, recursively).
int diskBytes(String path) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.file) return File(path).lengthSync();
  if (type != FileSystemEntityType.directory) return 0;
  var sum = 0;
  for (final e in Directory(
    path,
  ).listSync(recursive: true, followLinks: false)) {
    if (e is File) sum += e.lengthSync();
  }
  return sum;
}
