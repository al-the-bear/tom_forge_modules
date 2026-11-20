// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// What every measure of the harness shares: the run's configuration, YAML
/// output, process memory, frame statistics, images. The fidelity and
/// save-roundtrip comparisons are the runner's (`run_evaluation.py`).
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

  /// Minutes of the editing session after which memory is sampled (run 1).
  static const editMinutes = int.fromEnvironment(
    'EVAL_EDIT_MINUTES',
    defaultValue: 10,
  );

  /// The measures to take (their names in the trail, e.g. `page,engine`),
  /// comma-separated; empty: all. For checking one measure.
  static const measures = String.fromEnvironment('EVAL_MEASURES');

  static bool takes(String name) =>
      measures.isEmpty || measures.split(',').contains(name);

  /// The routes to run (`lok`, `zetaoffice`), comma-separated; empty: both.
  static const only = String.fromEnvironment('EVAL_ONLY');

  static bool runs(String route) =>
      only.isEmpty || only.split(',').contains(route);

  /// This run's number, 1–3.
  static const run = int.fromEnvironment('EVAL_RUN', defaultValue: 1);

  /// The Forge commit, the Flutter version (from the runner).
  static const forgeCommit = String.fromEnvironment('EVAL_FORGE_COMMIT');
  static const flutterVersion = String.fromEnvironment('EVAL_FLUTTER');

  /// Run 1 also takes the measures that are no timings (screenshots,
  /// fidelity exports, the dialog checklist, the editing session).
  static bool get first => run == 1;

  /// A sample: the core files and damaged copies from the sample set, the
  /// older formats from the scratch folder's `older/`.
  static String sample(String name) => evalOlderFiles.contains(name)
      ? '${Directory(work).parent.path}/older/$name'
      : '$samples/$name';

  /// [name] copied into [folder] of this run's scratch folder.
  static String copy(String name, String folder) {
    final dir = Directory('$work/$folder')..createSync(recursive: true);
    final target = '${dir.path}/$name';
    File(sample(name)).copySync(target);
    return target;
  }
}

/// The core office files the measures run on (samples.yaml), by id.
const evalCoreFiles = [
  'letter.docx',
  'letter.odt',
  'report.docx',
  'report.odt',
  'sheet.xlsx',
  'sheet.ods',
  'deck.pptx',
  'deck.odp',
];

/// `EVAL_FILES` (comma-separated sample names) replaces the files of the
/// fidelity exports and the round trips: a reduction run over variants of one
/// sample (`EVAL_SAMPLES` then names their folder). Empty keeps the lists.
const _evalFiles = String.fromEnvironment('EVAL_FILES');

/// [defaults], or the `EVAL_FILES` list when one is given.
List<String> evalFilesOr(List<String> defaults) =>
    _evalFiles.isEmpty ? defaults : _evalFiles.split(',');

/// The older formats (DPOE-2), made from the core files by the runner with
/// desktop LibreOffice before the runs (in the scratch folder).
const evalOlderFiles = ['report.doc', 'sheet.xls', 'deck.ppt'];

/// The damaged copies (samples.yaml), one per office format.
const evalDamagedFiles = [
  'damaged-docx.docx',
  'damaged-odt.odt',
  'damaged-xlsx.xlsx',
  'damaged-ods.ods',
  'damaged-pptx.pptx',
  'damaged-odp.odp',
];

/// The word the scripted edit types (at the start, into a cell, into a
/// slide's first object).
const evalEditWord = 'EVALEDIT';

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
    '# The $route route, run ${EvalConfig.run} of the office evaluation '
    '(officeproto31g).\n# Written by tom_forge_office_editors/tool/evaluation; '
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
