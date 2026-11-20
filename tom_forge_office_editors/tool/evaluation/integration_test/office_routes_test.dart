// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// The office routes' evaluation (office/PDF prototype, `part-evaluation`):
/// the LibreOfficeKit route (`lok`: `TomOfficeEditor` over the helper from
/// the binaries layer and the installed LibreOffice) and the ZetaOffice
/// route (`zetaoffice`: `TomZetaOfficeView` in the webview), measured the
/// same way over the sample set:
///
/// - every run: start (cold and warm) and open, editing latency (key to
///   repainted frame, with the helper's breakdown), scrolling and zoom
///   frames, memory, the save roundtrips (the saved files, compared by the
///   runner);
/// - run 1 also: the fidelity exports (the runner compares them with the
///   references), screenshots, the editing session's memory, three
///   documents open, crash isolation, the dialog checklist (native route),
///   the feature checklist and the engine checks against the fakes.
///
/// Results: `results/<route>/run-<n>.yaml` (and a JSON copy for the
/// runner). Started by `run_evaluation.py`; `--dart-define=EVAL_ONLY=lok`
/// runs one route.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tom_forge_office_route_evaluation/eval_support.dart';
import 'package:tom_forge_office_route_evaluation/main.dart';
import 'package:tom_office_editor/io.dart';
import 'package:tom_office_editor/tom_office_editor.dart';
import 'package:tom_office_editor/zetaoffice.dart';
import 'package:tom_office_protocol/tom_office_protocol.dart';

void _step(String what) => print('[eval] $what');

int get _now => evalClock.elapsedMicroseconds;

/// When each tile's decode started and ended (the last 4000): the latency
/// breakdown splits the way from the tile's arrival to its storing into the
/// wait before the decode starts, the decoder call, and what follows it.
final _decodes = <({int start, int end})>[];

Future<ui.Image> _timedDecode(
  Uint8List pixels,
  int width,
  int height,
  OfficePixelFormat format,
) async {
  final start = _now;
  final image = await decodeOfficeTile(pixels, width, height, format);
  _decodes.add((start: start, end: _now));
  if (_decodes.length > 4000) _decodes.removeRange(0, 1000);
  return image;
}

/// The time of every frame's build since [_recordFrames] (the last 4000).
final _frameTimes = <int>[];
var _framesRecorded = false;

/// Records a timestamp at the start of every frame (a persistent frame
/// callback runs in each frame's build phase, the frame that paints what
/// changed before it).
void _recordFrames() {
  if (_framesRecorded) return;
  _framesRecorded = true;
  SchedulerBinding.instance.addPersistentFrameCallback((_) {
    _frameTimes.add(_now);
    if (_frameTimes.length > 4000) _frameTimes.removeRange(0, 1000);
  });
}

double _ms(int us) => us / 1000;

Future<void> _until(
  WidgetTester tester,
  bool Function() done,
  String what, {
  int seconds = 60,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!done()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('no $what');
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Waits like [_until] but answers whether it happened instead of throwing.
Future<bool> _within(
  WidgetTester tester,
  bool Function() done, {
  int ms = 5000,
}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!done()) {
    if (DateTime.now().isAfter(end)) return false;
    await tester.pump(const Duration(milliseconds: 10));
  }
  return true;
}

Future<void> _wait(WidgetTester tester, [int ms = 300]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Runs [body] and keeps its answer, or its error as a not-measured entry:
/// one failing measure never stops the run.
Future<Object?> _measure(String name, Future<Object?> Function() body) async {
  if (!EvalConfig.takes(name)) {
    return notMeasured('not selected in this run (EVAL_MEASURES)');
  }
  try {
    _step('measure $name');
    return await body();
  } catch (e, s) {
    _step('$name failed: $e\n$s');
    return notMeasured('failed: $e');
  }
}

/// The scratch folder the runner reads the routes' outputs from.
String get _shared => Directory(EvalConfig.work).parent.path;

/// The physical footprint of every [pids] entry in MB, and their sum.
Map<String, Object?> _footprints(Map<String, int?> pids) {
  final out = <String, Object?>{};
  var sum = 0.0;
  for (final e in pids.entries) {
    final p = e.value;
    final mb = p == null ? null : footprintMb(p);
    out[e.key] = mb;
    if (mb != null) sum += mb;
  }
  out['total_mb'] = sum;
  return out;
}

/// FrameTimings reported while [body] runs.
Future<List<ui.FrameTiming>> _framesDuring(Future<void> Function() body) async {
  final timings = <ui.FrameTiming>[];
  void add(List<ui.FrameTiming> t) => timings.addAll(t);
  SchedulerBinding.instance.addTimingsCallback(add);
  try {
    await body();
  } finally {
    // Timings arrive in batches: let the last one in.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    SchedulerBinding.instance.removeTimingsCallback(add);
  }
  return timings;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late LibreOfficeInstallation installation;

  setUpAll(() async {
    installation = await TomLibreOfficeDetector().detect();
    _step('LibreOffice ${installation.state.name} ${installation.version}');
    Directory(EvalConfig.work).createSync(recursive: true);
  });

  if (EvalConfig.runs('lok')) {
    testWidgets('lok: the LibreOfficeKit route', (tester) async {
      await tester.binding.setSurfaceSize(null);
      final lok = _LokRoute(tester, installation);
      writeResults('lok', await lok.run());
    }, timeout: const Timeout(Duration(hours: 2)));
  }

  if (EvalConfig.runs('zetaoffice')) {
    testWidgets('zetaoffice: ZetaOffice in the webview', (tester) async {
      final zeta = _ZetaRoute(tester, installation);
      writeResults('zetaoffice', await zeta.run());
    }, timeout: const Timeout(Duration(hours: 2)));
  }
}

// ======================================================================
// The LibreOfficeKit route
// ======================================================================

class _LokRoute {
  _LokRoute(this.tester, this.installation)
    : launcher = RecordingLauncher(installation);

  final WidgetTester tester;
  final LibreOfficeInstallation installation;
  final RecordingLauncher launcher;
  final _open = <TomOfficeEditorController>[];

  Future<Map<String, Object?>> run() async {
    final r = <String, Object?>{};
    if (!installation.isUsable) {
      r['environment'] = environmentInfo();
      r['not_measured'] =
          'LibreOffice detection answered ${installation.state.name}';
      return r;
    }
    // The first open of the run is the cold start (a new helper with a
    // fresh profile; LibreOffice's files maybe in the OS's cache).
    r['open_ms'] = await _measure('open', _opens);
    final hello = launcher.channels.isEmpty
        ? null
        : launcher.channels.first.record
              .map((e) => e.message)
              .whereType<OfficeHello>()
              .firstOrNull;
    r['environment'] = environmentInfo(
      engines: {
        'libreoffice': installation.version,
        'libreoffice_path': installation.bundlePath,
        'helper': hello?.helperVersion,
        'lok': hello?.lokVersion,
        'helper_protocol': hello?.protocol,
      },
    );
    r['editing_latency'] = await _measure('latency', _latency);
    r['scrolling'] = await _measure('scrolling', _scrolling);
    r['memory'] = await _measure('memory', _memory);
    r['save_roundtrip'] = await _measure('roundtrip', _roundtrips);
    if (EvalConfig.first) {
      r['fidelity_exports'] = await _measure('fidelity', _fidelityExports);
      r['screenshots'] = await _measure('screenshots', _screenshots);
      r['memory_editing_session'] = await _measure('session', _session);
      r['three_documents'] = await _measure('three', _threeDocuments);
      r['crash_isolation'] = await _measure('crash', _crash);
      r['dialog_checklist'] = await _measure('dialogs', _dialogs);
      r['feature_checklist'] = _features();
      r['engine_checks'] = await _measure('engine', _engineChecks);
    }
    await _closeAll();
    return r;
  }

  // --------------------------------------------------------------- opening

  /// Opens [paths] (the first shown, the others in 1-pixel tabs) and waits
  /// for the first's document; answers the first's controller.
  Future<TomOfficeEditorController> open(
    List<String> paths, {
    int seconds = 120,
    bool waitForTiles = true,
  }) async {
    await _closeAll();
    final controllers = [
      for (final p in paths)
        TomOfficeEditorController(
          host: EvalOfficeHost(p, launcher),
          decoder: _timedDecode,
        ),
    ];
    _open.addAll(controllers);
    await tester.pumpWidget(LokEvalApp(controllers: controllers));
    for (final c in controllers) {
      unawaited(c.open());
    }
    final c = controllers.first;
    await _until(
      tester,
      () =>
          c.state != TomOfficeEditorState.idle &&
          c.state != TomOfficeEditorState.opening,
      '${paths.first} opened',
      seconds: seconds,
    );
    for (final other in controllers.skip(1)) {
      await _until(
        tester,
        () =>
            other.state != TomOfficeEditorState.opening &&
            other.state != TomOfficeEditorState.idle,
        'the other documents',
        seconds: seconds,
      );
    }
    if (waitForTiles && c.state == TomOfficeEditorState.open) {
      await _within(tester, () => c.tiles.length >= 4, ms: 20000);
    }
    return c;
  }

  Future<void> _closeAll() async {
    for (final c in _open) {
      await c.close();
    }
    await tester.pumpWidget(const SizedBox());
    for (final c in _open) {
      c.dispose();
    }
    _open.clear();
    await _wait(tester, 200);
  }

  RecordingHelperChannel get _channel => launcher.channels.last;

  /// Open times: from the request to the document being open (accepting
  /// input) and to the first tile received; the first file is the cold
  /// start, the next ones warm.
  Future<Object?> _opens() async {
    final out = <String, Object?>{};
    var first = true;
    for (final name in [...evalCoreFiles, 'sheet-large.xlsx']) {
      final path = EvalConfig.copy(name, 'open');
      final t0 = _now;
      final c = await open([path], waitForTiles: false);
      final opened = _now;
      final channel = _channel;
      await _within(tester, () => c.tiles.length > 0, ms: 30000);
      final firstTile = channel.record
          .where((e) => !e.sent && e.message is OfficeTile)
          .map((e) => e.us)
          .firstOrNull;
      out[first ? '$name (cold)' : name] = {
        'state': c.state.name,
        'open': _ms(opened - t0),
        'first_tile': firstTile == null ? null : _ms(firstTile - t0),
        'accepting_input': c.state == TomOfficeEditorState.open
            ? _ms(opened - t0)
            : null,
        if (c.error != null) 'error': c.error,
      };
      first = false;
    }
    await _closeAll();
    return out;
  }

  // ---------------------------------------------------------- latency

  /// 100 keystrokes into the middle of a paragraph of `report` and into a
  /// cell of `sheet`: key sent → LibreOffice's first callback → tile
  /// requested → tile received → the frame showing it.
  Future<Object?> _latency() async {
    final out = <String, Object?>{};
    for (final (name, prepare) in [
      ('report.docx', () {}),
      ('sheet.xlsx', () {}),
    ]) {
      final c = await open([EvalConfig.copy(name, 'latency')]);
      prepare();
      // Into the middle of a paragraph: a few lines down, then the middle.
      await _focusDocument(c);
      if (name.startsWith('report')) {
        for (var i = 0; i < 12; i++) {
          c.key(VclKey.down);
        }
        for (var i = 0; i < 10; i++) {
          c.key(VclKey.right);
        }
        await _wait(tester, 800);
      }
      out[name] = await _keystrokes(c, 100);
      c.key(VclKey.escape);
      await _wait(tester, 300);
    }
    await _closeAll();
    return out;
  }

  Future<void> _focusDocument(TomOfficeEditorController c) async {
    final view = find.byType(TomOfficeDocumentView);
    if (view.evaluate().isNotEmpty) {
      await tester.tapAt(tester.getTopLeft(view.first) + const Offset(60, 60));
      await _wait(tester, 400);
    }
  }

  Future<Map<String, Object?>> _keystrokes(
    TomOfficeEditorController c,
    int count,
  ) async {
    final channel = _channel;
    final total = <num>[], engine = <num>[], dart = <num>[], pipe = <num>[];
    final decode = <num>[], frame = <num>[];
    final waitBefore = <num>[], decoderCall = <num>[], afterDecode = <num>[];
    final streamHop = <num>[];
    final ownPipe = <num>[], olderTiles = <num>[];
    // When a listener beside the controller's sees each tile: the stream's
    // own hop from the recording to the listeners.
    final seen = <int>[];
    final sub = channel.events.listen((e) {
      if (e is OfficeTile) seen.add(_now);
    });
    var missed = 0;
    const letters = 'evaluationkeystrokes';
    // When the tile revision moves (a tile decoded and stored), and when each
    // frame starts: the tile's way to the screen, without polling for it.
    _recordFrames();
    final revisions = <int>[];
    void revised() => revisions.add(_now);
    c.tileRevision.addListener(revised);
    for (var i = 0; i < count; i++) {
      final from = channel.record.length;
      final tKey = _now;
      c.typeText(letters[i % letters.length]);
      int? callback, request, tile, ownRequest;
      var older = 0;
      // This key's callback, then the first tile requested and received
      // after it.
      final answered = await _within(tester, () {
        final after = channel.record.sublist(from);
        callback ??= after
            .where((e) => !e.sent && e.message is OfficeCallback)
            .map((e) => e.us)
            .firstOrNull;
        if (callback == null) return false;
        request ??= after
            .where(
              (e) =>
                  e.sent && e.message is OfficeRenderTile && e.us >= callback!,
            )
            .map((e) => e.us)
            .firstOrNull;
        if (request == null) return false;
        // The first tile that answers one of the requests sent after the
        // callback (by its id): an answer to an older request is one the
        // controller drops as superseded.
        final asked = <int, int>{
          for (final e in after)
            if (e.sent && e.message is OfficeRenderTile && e.us >= callback!)
              (e.message as OfficeRenderTile).id: e.us,
        };
        final hit = after
            .where(
              (e) =>
                  !e.sent &&
                  e.message is OfficeTile &&
                  asked.containsKey((e.message as OfficeTile).id),
            )
            .firstOrNull;
        if (hit == null) return false;
        tile = hit.us;
        ownRequest = asked[(hit.message as OfficeTile).id];
        older = after
            .where(
              (e) =>
                  !e.sent &&
                  e.message is OfficeTile &&
                  e.us >= request! &&
                  e.us < hit.us &&
                  !asked.containsKey((e.message as OfficeTile).id),
            )
            .length;
        return true;
      }, ms: 3000);
      if (!answered) {
        missed++;
        await _wait(tester, 100);
        continue;
      }
      // The tile decoded and stored: the first revision after it; then the
      // first frame after that, which paints it.
      int? firstAfter(List<int> times, int t) {
        for (final x in times) {
          if (x >= t) return x;
        }
        return null;
      }

      int? tRev, tFrame;
      final shown = await _within(tester, () {
        tRev ??= firstAfter(revisions, tile!);
        if (tRev == null) return false;
        tFrame = firstAfter(_frameTimes, tRev!);
        return tFrame != null;
      }, ms: 3000);
      if (!shown) {
        missed++;
        await _wait(tester, 100);
        continue;
      }
      total.add(_ms(tFrame! - tKey));
      engine.add(_ms(callback! - tKey));
      dart.add(_ms(request! - callback!));
      pipe.add(_ms(tile! - request!));
      ownPipe.add(_ms(tile! - ownRequest!));
      olderTiles.add(older);
      decode.add(_ms(tRev! - tile!));
      frame.add(_ms(tFrame! - tRev!));
      // The first decode started after the tile arrived (the controller
      // decodes a tile as soon as it is handled).
      final d = _decodes.where((x) => x.start >= tile!).firstOrNull;
      final s = seen.where((x) => x >= tile!).firstOrNull;
      if (s != null) streamHop.add(_ms(s - tile!));
      if (d != null && d.end <= tRev!) {
        waitBefore.add(_ms(d.start - tile!));
        decoderCall.add(_ms(d.end - d.start));
        afterDecode.add(_ms(tRev! - d.end));
      }
      await _wait(tester, 40);
    }
    c.tileRevision.removeListener(revised);
    await sub.cancel();
    return {
      'keystrokes': count,
      'without_tile_in_3_s': missed,
      'key_to_frame_ms': distribution(total),
      'breakdown_ms': {
        'key_to_first_callback (LibreOffice)': distribution(engine),
        'callback_to_tile_request (Dart)': distribution(dart),
        'tile_request_to_tile (pipe and rendering)': distribution(pipe),
        'of which: its own request to the tile': distribution(ownPipe),
        'older tiles received before it (dropped as superseded)': distribution(
          olderTiles,
        ),
        'tile_to_stored (decode)': distribution(decode),
        'of which: tile_to_decode_start (waiting on the UI isolate)':
            distribution(waitBefore),
        'of which: decoder_call': distribution(decoderCall),
        'the tile seen by a listener beside the controller': distribution(
          streamHop,
        ),
        'of which: decoded_to_stored': distribution(afterDecode),
        'stored_to_frame (the next frame starts)': distribution(frame),
      },
      'measured_by':
          'the recorded helper channel (key sent, LibreOffice\'s first '
          'callback, tile requested, tile received, timestamped), the tile '
          'revision\'s change (the tile decoded and stored) and the start of '
          'the first frame after it (a persistent frame callback)',
    };
  }

  // -------------------------------------------------------- scrolling

  ScrollPosition? _vertical() {
    final scrollables = find.descendant(
      of: find.byType(TomOfficeDocumentView),
      matching: find.byType(Scrollable),
    );
    for (final e in scrollables.evaluate()) {
      final state = (e as StatefulElement).state as ScrollableState;
      if (state.position.axis == Axis.vertical) return state.position;
    }
    return null;
  }

  /// A scripted scroll through `report` and `sheet-large` (10 s, at most 40
  /// screens), and the zoom from 50 % to its largest step on `report`.
  Future<Object?> _scrolling() async {
    final out = <String, Object?>{};
    for (final name in ['report.docx', 'sheet-large.xlsx']) {
      await open([EvalConfig.copy(name, 'scroll')]);
      final position = _vertical();
      if (position == null) {
        out[name] = notMeasured('no vertical scroll view found');
        continue;
      }
      final distance = (position.viewportDimension * 40).clamp(
        0.0,
        position.maxScrollExtent,
      );
      final frames = await _framesDuring(() async {
        unawaited(
          position.animateTo(
            distance,
            duration: const Duration(seconds: 10),
            curve: Curves.linear,
          ),
        );
        await _wait(tester, 10300);
      });
      out[name] = {
        'scripted':
            'an animated scroll of ${distance.round()} px in 10 s at the '
            'opened zoom',
        ...frameStats(frames),
      };
    }
    final c = await open([EvalConfig.copy('report.docx', 'scroll')]);
    await _focusDocument(c);
    final zoomOut = find.byKey(const ValueKey('ribbon-zoomOut'));
    final zoomIn = find.byKey(const ValueKey('ribbon-zoomIn'));
    final viewTab = find.byKey(const ValueKey('ribbon-tab-View'));
    if (viewTab.evaluate().isNotEmpty) await tester.tap(viewTab);
    await _wait(tester, 300);
    if (zoomIn.evaluate().isEmpty) {
      out['zoom'] = notMeasured('the ribbon has no zoom buttons');
    } else {
      for (var i = 0; i < 6; i++) {
        await tester.tap(zoomOut);
        await _wait(tester, 150);
      }
      final from = c.zoom;
      final frames = await _framesDuring(() async {
        for (var i = 0; i < kOfficeZoomSteps.length; i++) {
          await tester.tap(zoomIn);
          await _wait(tester, 400);
        }
      });
      out['zoom $from % to ${c.zoom} % (report)'] = {
        'scripted':
            'the ribbon\'s zoom in, one step every 400 ms '
            '(the view\'s steps: ${kOfficeZoomSteps.join(', ')} %)',
        ...frameStats(frames),
      };
    }
    await _closeAll();
    return out;
  }

  // ----------------------------------------------------------- memory

  Map<String, int?> _pids() => {
    'forge (this app)': pid,
    for (final ch in launcher.channels.where((c) => c.helperPid != null))
      'helper ${ch.helperPid}': ch.helperPid,
  };

  /// The footprints after open and after scrolling through, per file.
  Future<Object?> _memory() async {
    final out = <String, Object?>{};
    for (final name in ['report.docx', 'sheet-large.xlsx', 'deck.pptx']) {
      launcher.channels.clear();
      final c = await open([EvalConfig.copy(name, 'memory')]);
      final afterOpen = _footprints(_pids());
      final position = _vertical();
      if (position != null) {
        unawaited(
          position.animateTo(
            (position.viewportDimension * 40).clamp(
              0.0,
              position.maxScrollExtent,
            ),
            duration: const Duration(seconds: 8),
            curve: Curves.linear,
          ),
        );
        await _wait(tester, 8500);
      } else {
        for (var i = 0; i < c.parts && i < 30; i++) {
          c.setPart(i);
          await _wait(tester, 250);
        }
      }
      out[name] = {
        'after_open_mb': afterOpen,
        'after_scrolling_mb': _footprints(_pids()),
      };
    }
    await _closeAll();
    return out;
  }

  /// [EvalConfig.editMinutes] minutes of typing into `report`, then the
  /// footprints.
  Future<Object?> _session() async {
    launcher.channels.clear();
    final c = await open([EvalConfig.copy('report.docx', 'session')]);
    await _focusDocument(c);
    final before = _footprints(_pids());
    final start = DateTime.now();
    final end = start.add(Duration(minutes: EvalConfig.editMinutes));
    var keys = 0;
    // Every 30 s the footprints are sampled: the session's peak, not only
    // its end.
    final samples = <Map<String, Object?>>[];
    var nextSample = start.add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(end)) {
      c.typeText('w');
      keys++;
      if (keys % 60 == 0) c.key(VclKey.enter);
      await _wait(tester, 200);
      if (DateTime.now().isAfter(nextSample)) {
        samples.add({
          's': DateTime.now().difference(start).inSeconds,
          ..._footprints(_pids()),
        });
        nextSample = nextSample.add(const Duration(seconds: 30));
      }
    }
    final after = _footprints(_pids());
    await _closeAll();
    num peakOf(String key) => [
      before,
      ...samples,
      after,
    ].map((m) => (m[key] as num?) ?? 0).reduce((a, b) => a > b ? a : b);
    return {
      'minutes': EvalConfig.editMinutes,
      'keystrokes': keys,
      'before_mb': before,
      'after_mb': after,
      'peak_mb': {
        'forge (this app)': peakOf('forge (this app)'),
        'total_mb': peakOf('total_mb'),
      },
      'samples_every_30_s': samples,
    };
  }

  /// `report`, `sheet` and `deck` open at once: one helper per document.
  Future<Object?> _threeDocuments() async {
    launcher.channels.clear();
    await open([
      EvalConfig.copy('report.docx', 'three'),
      EvalConfig.copy('sheet.xlsx', 'three'),
      EvalConfig.copy('deck.pptx', 'three'),
    ]);
    final pids = {for (final c in launcher.channels) c.helperPid};
    final out = {
      'documents': 3,
      'helpers': pids.whereType<int>().length,
      'one_helper_per_document': pids.whereType<int>().length == 3,
      'footprints_mb': _footprints(_pids()),
    };
    await _closeAll();
    return out;
  }

  // -------------------------------------------------------- roundtrips

  /// Every core file and the older formats saved unchanged and after the
  /// scripted edit; the saved files go to `roundtrip/lok/` of the scratch
  /// folder for the runner's comparison.
  Future<Object?> _roundtrips() async {
    final out = <String, Object?>{};
    final dir = Directory('${EvalConfig.work}/roundtrip/lok')
      ..createSync(recursive: true);
    for (final name in evalFilesOr([...evalCoreFiles, ...evalOlderFiles])) {
      final path = EvalConfig.copy(name, 'roundtrip/lok-work');
      final stem = name.substring(0, name.lastIndexOf('.'));
      final ext = name.substring(name.lastIndexOf('.') + 1);
      final entry = <String, Object?>{};
      try {
        final c = await open([path]);
        if (c.state != TomOfficeEditorState.open) {
          out[name] = {'opened': false, 'state': c.state.name};
          continue;
        }
        final unchanged = await c.save();
        await _wait(tester, 300);
        entry['unchanged_save'] = unchanged.name;
        if (unchanged == TomOfficeSaveOutcome.saved) {
          File(path).copySync('${dir.path}/$stem.unchanged.$ext');
        }
        await _focusDocument(c);
        await _edit(c, name);
        entry['dirty_after_edit'] = c.isDirty;
        final edited = await c.save();
        await _wait(tester, 300);
        entry['edited_save'] = edited.name;
        if (edited == TomOfficeSaveOutcome.saved) {
          File(path).copySync('${dir.path}/$stem.edited.$ext');
        }
      } catch (e) {
        entry['error'] = '$e';
      }
      out[name] = entry;
    }
    await _closeAll();
    return out;
  }

  /// The scripted edit: a word typed at the start of a text, into the
  /// selected cell (A1), into a slide's first object (Tab selects it, Enter
  /// starts its text).
  Future<void> _edit(TomOfficeEditorController c, String name) async {
    final kind = c.docType;
    if (kind == OfficeDocType.spreadsheet) {
      c.key(VclKey.home | VclKey.mod1); // Cmd+Home: A1
      await _wait(tester, 300);
      c.commitText(evalEditWord);
      c.key(VclKey.enter);
    } else if (kind == OfficeDocType.presentation) {
      c.key(VclKey.tab);
      await _wait(tester, 400);
      c.key(VclKey.enter);
      await _wait(tester, 400);
      c.key(VclKey.home | VclKey.mod1);
      c.commitText('$evalEditWord ');
      await _wait(tester, 300);
      c.key(VclKey.escape);
      c.key(VclKey.escape);
    } else {
      // Into the body first: _focusDocument taps near the page's top, which
      // in a letter is its header, and Cmd+Home in a header stays there
      // (the text export leaves headers out). The middle of the view is the
      // first page's body.
      final view = find.byType(TomOfficeDocumentView);
      if (view.evaluate().isNotEmpty) {
        await tester.tapAt(tester.getCenter(view.first));
        await _wait(tester, 400);
      }
      c.key(VclKey.home | VclKey.mod1); // the start of the body
      await _wait(tester, 300);
      c.commitText('$evalEditWord ');
    }
    await _within(tester, () => c.isDirty, ms: 5000);
    await _wait(tester, 500);
  }

  // ---------------------------------------------------------- fidelity

  /// The route's rendering of every core file as the route's own PDF export
  /// (`save` with format `pdf` in a helper of its own: the same LibreOffice
  /// layout the tiles show), for the runner's page comparison.
  Future<Object?> _fidelityExports() async {
    final out = <String, Object?>{};
    final dir = Directory('$_shared/fidelity/lok')..createSync(recursive: true);
    for (final name in evalFilesOr(evalCoreFiles)) {
      final path = EvalConfig.copy(name, 'fidelity');
      final target = '${dir.path}/$name.pdf';
      out[name] = await _exportPdf(path, target);
    }
    return out;
  }

  Future<Object?> _exportPdf(String path, String target) async {
    final channel = await launcher.start(documentPath: path);
    final events = <OfficeHelperEvent>[];
    final sub = channel.events.listen(events.add);
    try {
      await _until(tester, () => events.any((e) => e is OfficeHello), 'hello');
      channel.send(OfficeOpen(path: path, readOnly: true, language: 'en-US'));
      await _until(
        tester,
        () => events.any((e) => e is OfficeOpened || e is OfficeError),
        'opened',
        seconds: 120,
      );
      if (!events.any((e) => e is OfficeOpened)) {
        return notMeasured('did not open: ${events.whereType<OfficeError>()}');
      }
      final t0 = _now;
      channel.send(
        OfficeSave(id: 1, targetPath: target, format: 'pdf', filterOptions: ''),
      );
      await _until(
        tester,
        () => events.any((e) => e is OfficeSaved),
        'exported',
        seconds: 180,
      );
      final saved = events.whereType<OfficeSaved>().first;
      return {
        'exported': saved.ok,
        'ms': _ms(_now - t0),
        if (!saved.ok) 'error': saved.error,
        if (saved.ok) 'pdf': target.split('/fidelity/').last,
      };
    } finally {
      await sub.cancel();
      await channel.close();
    }
  }

  /// The route as a Forge tab shows each core file (run 1).
  Future<Object?> _screenshots() async {
    final out = <String, Object?>{};
    for (final name in evalCoreFiles) {
      await open([EvalConfig.copy(name, 'shots')]);
      await _wait(tester, 1500);
      final shot =
          '${EvalConfig.results}/lok/screenshots/${name.replaceAll('.', '_')}.png';
      out[name] = await _boundaryShot(shot);
    }
    await _closeAll();
    return out;
  }

  Future<Object?> _boundaryShot(String out) async {
    final boundary =
        lokViewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return notMeasured('no view');
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(out)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    return out.split('/results/').last;
  }

  // ------------------------------------------------------------- crash

  /// `kill -9` of a helper with unsaved changes while a second document
  /// stays open; then every damaged file.
  Future<Object?> _crash() async {
    final out = <String, Object?>{};
    final reportPath = EvalConfig.copy('report.docx', 'crash');
    final otherPath = EvalConfig.copy('letter.docx', 'crash');
    launcher.channels.clear();
    final c = await open([reportPath, otherPath]);
    final other = _open[1];
    final before = File(reportPath).readAsBytesSync();
    await _focusDocument(c);
    c.commitText('unsaved ');
    await _within(tester, () => c.isDirty, ms: 5000);
    final victim = launcher.channels
        .firstWhere(
          (ch) => ch.record.any(
            (e) =>
                e.sent &&
                e.message is OfficeOpen &&
                (e.message as OfficeOpen).path == reportPath,
          ),
        )
        .helperPid;
    final t0 = _now;
    if (victim != null) Process.killPid(victim, ProcessSignal.sigkill);
    final noticed = await _within(
      tester,
      () => c.state == TomOfficeEditorState.stopped,
      ms: 30000,
    );
    final noticedMs = _ms(_now - t0);
    final message = c.stopDescription;
    other.commitText('x');
    final otherAnswers = await _within(tester, () => other.isDirty, ms: 5000);
    await c.reopen();
    final reopened = await _within(
      tester,
      () => c.state == TomOfficeEditorState.open,
      ms: 60000,
    );
    out['helper_killed_during_edit'] = {
      'forge_running': true,
      'tab_noticed': noticed,
      'noticed_ms': noticed ? noticedMs : null,
      'tab_message': 'LibreOffice stopped: $message',
      'other_tab_unaffected':
          other.state == TomOfficeEditorState.open && otherAnswers,
      'lost': listEquals(before, File(reportPath).readAsBytesSync())
          ? 'the unsaved edit (the file on disk unchanged)'
          : 'the file on disk changed',
      'reopens': reopened,
    };
    await _closeAll();
    final damaged = <String, Object?>{};
    for (final name in evalDamagedFiles) {
      final host = EvalOfficeHost(EvalConfig.copy(name, 'damaged'), launcher);
      final controller = TomOfficeEditorController(host: host);
      _open.add(controller);
      await tester.pumpWidget(LokEvalApp(controllers: [controller]));
      unawaited(controller.open());
      await _within(
        tester,
        () =>
            controller.state != TomOfficeEditorState.idle &&
            controller.state != TomOfficeEditorState.opening,
        ms: 60000,
      );
      damaged[name] = {
        'forge_running': true,
        'state': controller.state.name,
        'tab_message': ?controller.error,
        if (controller.state == TomOfficeEditorState.stopped)
          'stopped': controller.stopDescription,
        'notices': host.notices,
      };
      await _closeAll();
    }
    out['damaged_files'] = damaged;
    out['encrypted'] = notMeasured(
      'the sample set has no password-protected office file '
      '(pdf-encrypted is the PDF routes\')',
    );
    return out;
  }

  // ----------------------------------------------------------- dialogs

  /// The ribbon control [id]'s UNO command for [type] (what its button
  /// sends).
  (String, String)? _ribbonCommand(OfficeDocType type, String id) {
    for (final tab in officeRibbonTabs(type)) {
      for (final group in tab.groups) {
        for (final control in group.controls) {
          if (control.id == id && control is RibbonCommand) {
            return (control.command, control.args);
          }
        }
      }
    }
    return null;
  }

  /// The dialog checklist in window mode (opened with its ribbon control's
  /// command, painted, answering Tab, closed by Escape) and in JSON mode;
  /// one image per dialog, window mode beside JSON mode.
  Future<Object?> _dialogs() async {
    final out = <String, Object?>{};
    Future<void> check(
      TomOfficeEditorController c,
      String name,
      String control,
      String title, {
      List<(int, int)> clicks = const [],
      String? then,
    }) async {
      try {
        final command =
            _ribbonCommand(c.docType, control) ??
            (control == 'find' ? ('.uno:SearchDialog', '') : null);
        if (command == null) throw StateError('no ribbon command $control');
        c.uno(command.$1, command.$2);
        var w = await _dialog(c, title);
        if (w != null && clicks.isNotEmpty && then != null) {
          // The way to the colour dialog: clicks on the dialog, as a person
          // makes them (its Background page, Color, Pick...).
          for (final (x, y) in clicks) {
            c.windowMouse(w.id, OfficeMouseEventType.down, x, y);
            c.windowMouse(w.id, OfficeMouseEventType.up, x, y);
            await _wait(tester, 900);
          }
          final parent = w;
          w = await _dialog(c, then);
          out[name] = {
            'opened_by': '${command.$1}, then clicks in $title',
            ...await _verdict(c, w, name),
          };
          c.windowKey(parent.id, VclKey.escape);
          await _within(
            tester,
            () => !c.windows.any((x) => x.id == parent.id),
            ms: 5000,
          );
          if (c.windows.any((x) => x.id == parent.id)) {
            c.closeWindow(parent.id);
          }
          await _wait(tester, 500);
          return;
        }
        out[name] = {'opened_by': command.$1, ...await _verdict(c, w, name)};
      } catch (e) {
        out[name] = {'window_mode': 'fails', 'reason': '$e'};
      }
    }

    var c = await open([EvalConfig.copy('letter.docx', 'dialogs')]);
    c.key(VclKey.escape);
    await check(c, 'Character', 'characterDialog', 'Character');
    await check(c, 'Paragraph', 'paragraphDialog', 'Paragraph');
    await check(c, 'Find and Replace', 'find', 'Find and Replace');
    await check(c, 'Page Style', 'pageStyle', 'Page Style');
    c.setDialogMode(TomOfficeDialogMode.json);
    await _within(tester, () => c.jsonDialogsAvailable != null, ms: 10000);
    final jsonAvailable = c.jsonDialogsAvailable;
    c = await open([EvalConfig.copy('sheet.xlsx', 'dialogs')]);
    await check(c, 'Format Cells', 'formatCells', 'Format Cells');
    await check(
      c,
      'Colour dialog (Custom colour)',
      'formatCells',
      'Format Cells',
      clicks: const [(80, 219), (500, 30), (669, 278)],
      then: 'Pick a Color',
    );
    await check(c, 'Insert Chart', 'chart', 'Chart');
    c = await open([EvalConfig.copy('deck.pptx', 'dialogs')]);
    await check(c, 'Insert Table', 'table', 'Insert Table');
    await _closeAll();
    for (final e in out.values.whereType<Map<String, Object?>>()) {
      e['json_mode'] = jsonAvailable == false
          ? 'fails: LibreOffice\'s desktop build sends no JSON dialogs (the '
                'helper refuses dialogMode json; the tab stays in window mode)'
          : 'not checked (JSON dialogs answered $jsonAvailable)';
    }
    return out;
  }

  Future<TomOfficeWindow?> _dialog(
    TomOfficeEditorController c,
    String title,
  ) async {
    final ok = await _within(
      tester,
      () => c.windows.any((w) => w.isDialog && w.title.contains(title)),
      ms: 20000,
    );
    if (!ok) return null;
    final w = c.windows.lastWhere((w) => w.title.contains(title));
    await _within(tester, () => w.image != null, ms: 10000);
    return w;
  }

  Future<Map<String, Object?>> _verdict(
    TomOfficeEditorController c,
    TomOfficeWindow? w,
    String name,
  ) async {
    if (w == null) {
      return {
        'window_mode': 'fails',
        'reason':
            'no dialog in 20 s (windows: '
            '${c.windows.map((x) => '${x.kind} ${x.title}').toList()})',
      };
    }
    final image = w.image;
    final colours = image == null ? 0 : await _colours(image);
    final painted = colours > 8;
    final shot = image == null ? null : await _sideBySide(image, name);
    final before = w.changes;
    c.windowKey(w.id, VclKey.tab);
    final answers = await _within(tester, () => w.changes > before, ms: 8000);
    c.windowKey(w.id, VclKey.escape);
    final closed = await _within(
      tester,
      () => !c.windows.any((x) => x.id == w.id),
      ms: 10000,
    );
    if (!closed) c.closeWindow(w.id);
    return {
      'window_mode': painted && answers && closed
          ? 'works'
          : painted
          ? 'works with flaws'
          : 'fails',
      'painted_colours': colours,
      'answers_tab': answers,
      'closes_on_escape': closed,
      'size': '${w.width}x${w.height}',
      'screenshot': ?shot,
    };
  }

  Future<int> _colours(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint32List().toSet().length;
  }

  /// The window-mode image beside the JSON-mode panel.
  Future<String> _sideBySide(ui.Image window, String name) async {
    final w = window.width.toDouble(), h = window.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w * 2 + 24, h + 40),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawImage(window, const Offset(0, 40), Paint());
    canvas.drawRect(
      Rect.fromLTWH(w + 24, 40, w, h),
      Paint()..color = const Color(0xFFEEEEEE),
    );
    void text(String s, Offset at, {double width = 600}) {
      final p = TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(color: Color(0xFF202020), fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      p.paint(canvas, at);
    }

    text('$name — window mode', const Offset(4, 12));
    text('JSON mode', Offset(w + 28, 12));
    text(
      'LibreOffice\'s desktop build sends no JSON dialogs: the helper refuses '
      'dialogMode json and the tab stays in window mode.',
      Offset(w + 40, 60),
      width: w - 32,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage((w * 2 + 24).round(), (h + 40).round());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file =
        '${EvalConfig.results}/lok/screenshots/dialogs/'
        '${name.replaceAll(RegExp(r'[^A-Za-z]+'), '_')}.png';
    File(file)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    return file.split('/results/').last;
  }

  // ---------------------------------------------------------- features

  /// The feature checklist, read from the ribbon of each document type and
  /// the editor's own views.
  Map<String, Object?> _features() {
    Set<String> commands(OfficeDocType type) => {
      for (final tab in officeRibbonTabs(type))
        for (final group in tab.groups)
          for (final control in group.controls)
            switch (control) {
              RibbonCommand(:final command) => command,
              RibbonChoice(:final command) => command,
              _ => control.id,
            },
    };
    final text = commands(OfficeDocType.text);
    final sheet = commands(OfficeDocType.spreadsheet);
    final slides = commands(OfficeDocType.presentation);
    final all = {...text, ...sheet, ...slides};
    String has(Set<String> set, List<String> any) =>
        any.any(set.contains) ? 'present' : 'missing';
    return {
      'styles': has(text, ['.uno:StyleApply']),
      'find and replace': has(all, ['.uno:SearchDialog', 'find']),
      'tables': has(all, ['.uno:InsertTable']),
      'images': has(all, ['.uno:InsertGraphic', 'insertImage']),
      'comments': has(all, ['.uno:InsertAnnotation']),
      'tracked changes': has(text, ['.uno:TrackChanges']),
      'formula bar': 'present (the editor\'s formula line)',
      'sheet tabs': 'present (the editor\'s sheet tabs)',
      'slide sorter and notes':
          'partial (the slide strip with thumbnails; no notes view)',
      'spelling': has(all, ['.uno:SpellingAndGrammarDialog']),
      'printing': has(all, ['.uno:Print']),
      'source': 'the ribbon model (officeRibbonTabs) and the editor\'s views',
    };
  }

  // ------------------------------------------------------ engine checks

  /// The fake's modelled behaviour (ScriptedOfficeHelper,
  /// tom_forge_office_editors_testing) against the real LibreOffice.
  Future<Object?> _engineChecks() async {
    final c = await open([EvalConfig.copy('report.docx', 'engine')]);
    await _focusDocument(c);
    final checks = <String, Object?>{};
    void check(String what, Object? fake, Object? real) => checks[what] = {
      'fake': fake,
      'libreoffice': real,
      'matches': fake == real,
    };
    check('clean after open', false, c.isDirty);
    check('nothing to undo after open', false, c.canUndo);
    c.commitText('a');
    await _within(tester, () => c.canUndo && c.isDirty, ms: 5000);
    check('an edit: dirty', true, c.isDirty);
    check('an edit: undo enabled', true, c.canUndo);
    c.undo();
    await _within(tester, () => c.canRedo, ms: 5000);
    check('undo: redo enabled', true, c.canRedo);
    // The modified flag comes in its own callback, after the history's: give
    // it time to arrive before reading it (it stays set if the engine keeps
    // it).
    await _within(tester, () => !c.isDirty, ms: 3000);
    check(
      'undo back to the saved state: clean (the modified flag follows it)',
      false,
      c.isDirty,
    );
    c.redo();
    await _wait(tester, 800);
    check('redo: undo enabled again', true, c.canUndo);
    c.undo();
    await _within(tester, () => c.canRedo, ms: 5000);
    c.commitText('b');
    await _within(tester, () => !c.canRedo, ms: 5000);
    check('a new edit after undo ends the redo', false, c.canRedo);
    await c.save();
    await _within(tester, () => !c.isDirty, ms: 5000);
    check('a save clears dirty', false, c.isDirty);
    await _closeAll();
    return {
      'checks': checks,
      'mismatches': [
        for (final e in checks.entries)
          if ((e.value! as Map)['matches'] != true) e.key,
      ],
    };
  }
}

// ======================================================================
// The ZetaOffice route
// ======================================================================

class _ZetaRoute {
  _ZetaRoute(this.tester, LibreOfficeInstallation installation)
    : launcher = RecordingLauncher(installation);

  final WidgetTester tester;
  final RecordingLauncher launcher;
  final files = TomZetaOfficeCache();
  TomZetaOfficeController? _c;
  final _pageAnswers = <Map<String, Object?>>[];
  StreamSubscription<Map<String, Object?>>? _sub;
  Set<int> _contentBefore = {};

  Future<Map<String, Object?>> run() async {
    final r = <String, Object?>{};
    final status = await files.status();
    if (status.state != TomZetaOfficeCacheState.ready) {
      final t0 = _now;
      await files.download();
      r['download'] = {'ms': _ms(_now - t0), 'reason': 'the cache was empty'};
    }
    r['open_ms'] = await _measure('open', _opens);
    r['environment'] = environmentInfo(
      engines: {
        'zetaoffice': (await files.status()).version,
        'zetaoffice_cache': files.folder,
      },
    );
    // Whether the page runs normally: ZetaOffice's event loop and every
    // measure through the page need its animation frames.
    await open(EvalConfig.copy('report.docx', 'zeta-probe'));
    final frames = await _measure('page', () async => _pageHasFrames());
    r['page'] = _probeResult ?? frames;
    final live = frames == true;
    Future<Object?> paged(String name, Future<Object?> Function() body) => live
        ? _measure(name, body)
        : Future.value(notMeasured(_noFramesReason));
    r['editing_latency'] = await paged('latency', _latency);
    r['scrolling'] = await paged('scrolling', _scrolling);
    r['memory'] = await _measure('memory', _memory);
    r['save_roundtrip'] = await paged('roundtrip', _roundtrips);
    if (EvalConfig.first) {
      r['download'] ??= await _measure('download', _download);
      r['fidelity_exports'] = await paged('fidelity', _fidelityExports);
      r['screenshots'] = await paged('screenshots', _screenshots);
      r['memory_editing_session'] = await paged('session', _session);
      r['three_documents'] = notMeasured(
        'ZetaOffice runs in one tab at a time (a second tab says so)',
      );
      // Written before the crash measure: if the app goes down with the
      // killed content process, the run's other results stay.
      writeResults('zetaoffice', {
        ...r,
        'crash_isolation': notMeasured(
          'the evaluation app ended during the crash measure (the web '
          'content process killed): Forge would have gone down with it',
        ),
      });
      r['crash_isolation'] = await _measure('crash', _crash);
      r['dialog_checklist'] = notMeasured(
        'the checklist is the native route\'s (part-evaluation, measure 7); '
        'ZetaOffice shows LibreOffice\'s own dialogs in its full interface',
      );
      r['feature_checklist'] = await _measure('features', _features);
      r['engine_checks'] = await paged('engine', _engineChecks);
    }
    await _close();
    return r;
  }

  /// Opens [path] in a new tab (closing the one before) and waits until
  /// ZetaOffice shows it; answers its open time in ms.
  Future<double?> open(String path, {int seconds = 200}) async {
    await _close();
    _contentBefore = webContentPids();
    final c = _c = TomZetaOfficeController(
      host: EvalOfficeHost(path, launcher),
      files: files,
      serving: TomZetaOfficeServer(files: const TomBinaryFileAccess()),
    );
    _sub = c.pageMessagesForTest.listen((m) {
      if (m['type'] == 'measure') _pageAnswers.add(m);
    });
    await tester.pumpWidget(ZetaEvalApp(controller: c));
    final t0 = _now;
    await c.prepare();
    await _until(
      tester,
      () =>
          c.state == TomZetaOfficeState.open ||
          c.state == TomZetaOfficeState.failed ||
          c.state == TomZetaOfficeState.needsDownload,
      '$path in ZetaOffice',
      seconds: seconds,
    );
    return c.state == TomZetaOfficeState.open ? _ms(_now - t0) : null;
  }

  Future<void> _close() async {
    final c = _c;
    _c = null;
    await _sub?.cancel();
    _sub = null;
    if (c != null) {
      await c.close();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await _wait(tester, 500);
    }
  }

  TomZetaOfficeController get c => _c!;

  Set<int> get _content => webContentPids().difference(_contentBefore);

  Map<String, int?> _pids() => {
    'forge (this app)': pid,
    for (final p in _content) 'webcontent $p': p,
  };

  Future<Object?> _opens() async {
    final out = <String, Object?>{};
    var first = true;
    for (final name in [...evalCoreFiles, 'sheet-large.xlsx']) {
      final ms = await open(EvalConfig.copy(name, 'zeta-open'));
      out[first ? '$name (cold: the WebAssembly compiled)' : name] = {
        'state': c.state.name,
        'open': ms,
        'accepting_input': ms,
        'first_tile': null,
        if (c.error != null) 'error': c.error,
      };
      first = false;
    }
    out['note'] =
        'open and accepting input are the same moment: the page answers '
        '`loaded` when ZetaOffice shows the document; there are no tiles';
    await _close();
    return out;
  }

  /// Runs [script] (its last expression a Promise of a JSON-able value) in
  /// the page and answers its value.
  Future<Object?> page(String name, String script, {int seconds = 120}) async {
    final id = '$name-$_now';
    final before = _pageAnswers.length;
    await c.runInPageForTest(
      '(async () => { let value; try { value = await ($script); } '
      'catch (e) { value = {error: String(e)}; } '
      'window.flutter_inappwebview.callHandler("forge", '
      '{type: "measure", id: "$id", value}); })();',
    );
    final ok = await _within(
      tester,
      () => _pageAnswers.skip(before).any((m) => m['id'] == id),
      ms: seconds * 1000,
    );
    if (!ok) throw TimeoutException('no answer from the page for $name');
    return _pageAnswers.skip(before).firstWhere((m) => m['id'] == id)['value'];
  }

  /// The page's facts the measures rely on: whether it is visible and
  /// whether WebKit gives it animation frames (in one second).
  static const _probe = '''
    (async () => {
      const c = document.getElementById('qtcanvas');
      let frames = 0;
      const t0 = performance.now();
      await new Promise(res => {
        const tick = () => {
          frames++;
          if (performance.now() - t0 < 1000) requestAnimationFrame(tick);
          else res();
        };
        requestAnimationFrame(tick);
        setTimeout(res, 1500);
      });
      return {
        canvas: c ? c.constructor.name : null,
        width: c ? c.width : null,
        crossOriginIsolated: window.crossOriginIsolated,
        visibilityState: document.visibilityState,
        animation_frames_in_1_s: frames,
      };
    })()''';

  /// Whether the page got animation frames (the probe, once per run).
  bool? _frames;

  Future<bool> _pageHasFrames() async {
    if (_frames != null) return _frames!;
    final v = await page('probe', _probe) as Map?;
    _probeResult = v;
    _frames = ((v?['animation_frames_in_1_s'] as num?) ?? 0) > 10;
    return _frames!;
  }

  Map? _probeResult;

  /// The reason the page's frame measures are not taken.
  String get _noFramesReason =>
      'the page got no animation frames (${_probeResult ?? '?'}): WebKit '
      'runs requestAnimationFrame only for a page a person can see, and the '
      'evaluation window was not visible on mbp\'s screen during this run; '
      'repeated with the window visible by the todo the evaluation files '
      'for it';

  /// [count] key events dispatched to the canvas in the page, each timed
  /// from its keydown to the second animation frame after it (the frame
  /// after the one the key was handled in).
  static String _keysScript(int count) =>
      '''
    (async () => {
      const c = document.getElementById('qtcanvas');
      c.focus();
      const frame = () => new Promise(r => requestAnimationFrame(r));
      const letters = 'evaluationkeystrokes';
      const times = [];
      for (let i = 0; i < $count; i++) {
        const key = letters[i % letters.length];
        const init = {key, code: 'Key' + key.toUpperCase(),
          keyCode: key.toUpperCase().charCodeAt(0), which: key.toUpperCase().charCodeAt(0),
          bubbles: true, cancelable: true};
        const t0 = performance.now();
        c.dispatchEvent(new KeyboardEvent('keydown', init));
        c.dispatchEvent(new KeyboardEvent('keypress', Object.assign({}, init,
          {keyCode: key.charCodeAt(0), which: key.charCodeAt(0), charCode: key.charCodeAt(0)})));
        c.dispatchEvent(new KeyboardEvent('keyup', init));
        await frame(); await frame();
        times.push(performance.now() - t0);
        await new Promise(r => setTimeout(r, 40));
      }
      return {times};
    })()''';

  Future<Object?> _latency() async {
    final out = <String, Object?>{};
    for (final name in ['report.docx', 'sheet.xlsx']) {
      await open(EvalConfig.copy(name, 'zeta-latency'));
      if (!await _pageHasFrames()) {
        out[name] = notMeasured(_noFramesReason);
        continue;
      }
      final before = await c.readForTest();
      final value = await page('keys', _keysScript(100)) as Map?;
      final after = await c.readForTest();
      final typed = after != before;
      final times = [
        for (final t in (value?['times'] as List? ?? [])) t as num,
      ];
      out[name] = {
        'keystrokes': times.length,
        'the_keys_reached_the_document': typed,
        'keydown_to_next_frames_ms': distribution(times),
        'measured_in':
            'the web page: keydown dispatched to ZetaOffice\'s canvas, timed '
            'to the second requestAnimationFrame after it (whole '
            'milliseconds); coarser than the native route\'s key-to-tile '
            'breakdown, and with no signal of when the canvas itself changed',
        if (!typed)
          'note':
              'the document text did not change: synthetic key events do not '
              'reach ZetaOffice, so these times are the page\'s frame times '
              'only',
      };
    }
    await _close();
    return out;
  }

  /// [frames] wheel events on the canvas, one per animation frame, timed by
  /// the frame intervals; with [zoom] the wheel holds Ctrl.
  static String _wheelScript(int frames, {bool zoom = false}) =>
      '''
    (async () => {
      const c = document.getElementById('qtcanvas');
      const r = c.getBoundingClientRect();
      const intervals = [];
      let last = performance.now();
      for (let i = 0; i < $frames; i++) {
        c.dispatchEvent(new WheelEvent('wheel', {deltaY: ${zoom ? '(i % 24 < 12 ? -60 : 60)' : '120'},
          deltaMode: 0, ctrlKey: $zoom, clientX: r.left + r.width / 2,
          clientY: r.top + r.height / 2, bubbles: true, cancelable: true}));
        await new Promise(res => requestAnimationFrame(res));
        const now = performance.now();
        intervals.push(now - last);
        last = now;
      }
      return {intervals};
    })()''';

  /// [count] wheel events on the canvas, one every 16 ms by timer (no
  /// frame timing: the memory samples only need the scroll).
  static String _wheelTimerScript(int count) =>
      '''
    (async () => {
      const c = document.getElementById('qtcanvas');
      const r = c.getBoundingClientRect();
      for (let i = 0; i < $count; i++) {
        c.dispatchEvent(new WheelEvent('wheel', {deltaY: 120, deltaMode: 0,
          clientX: r.left + r.width / 2, clientY: r.top + r.height / 2,
          bubbles: true, cancelable: true}));
        await new Promise(res => setTimeout(res, 16));
      }
      return {events: $count};
    })()''';

  Future<Object?> _scrolling() async {
    final out = <String, Object?>{};
    for (final name in ['report.docx', 'sheet-large.xlsx']) {
      await open(EvalConfig.copy(name, 'zeta-scroll'));
      if (!await _pageHasFrames()) {
        out[name] = notMeasured(_noFramesReason);
        continue;
      }
      final v = await page('scroll', _wheelScript(600)) as Map?;
      out[name] = {
        'scripted': '600 wheel events on the canvas, one per animation frame',
        'measured_in':
            'the web page (requestAnimationFrame intervals); coarser than '
            'Flutter\'s frame timings',
        ...intervalStats([for (final i in (v?['intervals'] as List)) i as num]),
      };
    }
    await open(EvalConfig.copy('report.docx', 'zeta-scroll'));
    if (!await _pageHasFrames()) {
      out['zoom (report, Ctrl+wheel in and out)'] = notMeasured(
        _noFramesReason,
      );
      await _close();
      return out;
    }
    final v = await page('zoom', _wheelScript(192, zoom: true)) as Map?;
    out['zoom (report, Ctrl+wheel in and out)'] = {
      'scripted': '192 Ctrl+wheel events, 12 frames in, 12 out, alternating',
      'measured_in': 'the web page (requestAnimationFrame intervals)',
      ...intervalStats([for (final i in (v?['intervals'] as List)) i as num]),
    };
    await _close();
    return out;
  }

  Future<Object?> _memory() async {
    final out = <String, Object?>{};
    for (final name in ['report.docx', 'sheet-large.xlsx', 'deck.pptx']) {
      await open(EvalConfig.copy(name, 'zeta-memory'));
      final afterOpen = _footprints(_pids());
      String? scrolled;
      try {
        if (_frames == true) {
          await page('scroll', _wheelScript(400));
        } else {
          // Without frames the wheel script would wait forever: the same
          // events by timer.
          await page('scroll', _wheelTimerScript(400), seconds: 60);
        }
      } catch (e) {
        scrolled = 'the page did not answer the scroll ($e)';
      }
      out[name] = {
        'after_open_mb': afterOpen,
        'after_scrolling_mb': _footprints(_pids()),
        'scroll': ?scrolled,
      };
    }
    await _close();
    return out;
  }

  Future<Object?> _session() async {
    await open(EvalConfig.copy('report.docx', 'zeta-session'));
    final before = _footprints(_pids());
    final end = DateTime.now().add(Duration(minutes: EvalConfig.editMinutes));
    var edits = 0;
    while (DateTime.now().isBefore(end)) {
      await c.editForTest('w');
      edits++;
      await _wait(tester, 400);
    }
    final after = _footprints(_pids());
    await _close();
    return {
      'minutes': EvalConfig.editMinutes,
      'edits': edits,
      'edited_by': 'UNO insertString through the page (a character each)',
      'before_mb': before,
      'after_mb': after,
    };
  }

  Future<Object?> _roundtrips() async {
    final out = <String, Object?>{};
    final dir = Directory('${EvalConfig.work}/roundtrip/zetaoffice')
      ..createSync(recursive: true);
    for (final name in evalFilesOr([...evalCoreFiles, ...evalOlderFiles])) {
      final path = EvalConfig.copy(name, 'roundtrip/zeta-work');
      final stem = name.substring(0, name.lastIndexOf('.'));
      final ext = name.substring(name.lastIndexOf('.') + 1);
      final entry = <String, Object?>{};
      try {
        final ms = await open(path);
        if (ms == null) {
          out[name] = {
            'opened': false,
            'state': c.state.name,
            'error': c.error,
          };
          continue;
        }
        final unchanged = await c.save();
        entry['unchanged_save'] = unchanged.name;
        if (unchanged == TomOfficeSaveOutcome.saved) {
          File(path).copySync('${dir.path}/$stem.unchanged.$ext');
        }
        await c.editForTest('$evalEditWord ');
        await _within(tester, () => c.isDirty, ms: 10000);
        entry['dirty_after_edit'] = c.isDirty;
        final edited = await c.save();
        entry['edited_save'] = edited.name;
        if (edited == TomOfficeSaveOutcome.saved) {
          File(path).copySync('${dir.path}/$stem.edited.$ext');
        }
      } catch (e) {
        entry['error'] = '$e';
      }
      out[name] = entry;
    }
    out['edit'] =
        'the word typed through UNO in the page (insertString at a text\'s '
        'start, A1\'s text, the first slide\'s first shape)';
    await _close();
    return out;
  }

  Future<Object?> _fidelityExports() async {
    final out = <String, Object?>{};
    final dir = Directory('$_shared/fidelity/zetaoffice')
      ..createSync(recursive: true);
    for (final name in evalFilesOr(evalCoreFiles)) {
      final ms = await open(EvalConfig.copy(name, 'zeta-fidelity'));
      if (ms == null) {
        out[name] = notMeasured('did not open: ${c.error}');
        continue;
      }
      final t0 = _now;
      final bytes = await c.exportPdfForTest();
      if (bytes == null) {
        out[name] = notMeasured(
          'the PDF export failed: ${c.exportErrorForTest ?? 'no reason'}',
        );
        continue;
      }
      File('${dir.path}/$name.pdf').writeAsBytesSync(bytes);
      out[name] = {
        'exported': true,
        'ms': _ms(_now - t0),
        'pdf': 'zetaoffice/$name.pdf',
      };
    }
    await _close();
    return out;
  }

  Future<Object?> _screenshots() async {
    final out = <String, Object?>{};
    for (final name in evalCoreFiles) {
      final ms = await open(EvalConfig.copy(name, 'zeta-shots'));
      if (ms == null) {
        out[name] = notMeasured('did not open');
        continue;
      }
      await _wait(tester, 2500);
      final png = await c.snapshotForTest();
      if (png == null) {
        out[name] = notMeasured('the webview gave no snapshot');
        continue;
      }
      final file =
          '${EvalConfig.results}/zetaoffice/screenshots/'
          '${name.replaceAll('.', '_')}.png';
      File(file)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png);
      out[name] = file.split('/results/').last;
    }
    await _close();
    return out;
  }

  /// The ZetaOffice download into a scratch cache: bytes and time.
  Future<Object?> _download() async {
    final folder = '${EvalConfig.work}/zeta-download';
    final scratch = TomZetaOfficeCache(folder: folder);
    final t0 = _now;
    var bytes = 0;
    await scratch.download(progress: (received, total) => bytes = received);
    final ms = _ms(_now - t0);
    final size = diskBytes(folder);
    Directory(folder).deleteSync(recursive: true);
    return {'bytes': bytes, 'ms': ms, 'cache_bytes': size};
  }

  Future<Object?> _crash() async {
    final out = <String, Object?>{};
    // A LibreOfficeKit tab beside it: the other tab.
    final other = TomOfficeEditorController(
      host: EvalOfficeHost(
        EvalConfig.copy('deck.pptx', 'zeta-crash'),
        launcher,
      ),
    );
    await other.open();
    final path = EvalConfig.copy('report.docx', 'zeta-crash');
    final before = File(path).readAsBytesSync();
    await open(path);
    if (_frames == true) {
      await c.editForTest('unsaved ');
      await _within(tester, () => c.isDirty, ms: 10000);
    }
    // Only this window's web content process: the pid WebKit gives for this
    // window's webview, killed in the evaluation app (MainFlutterWindow.swift),
    // never a pid search.
    final t0 = _now;
    final victims =
        await const MethodChannel(
          'eval/webkit',
        ).invokeListMethod<int>('killWebContent') ??
        const <int>[];
    final noticed = await _within(
      tester,
      () => c.state == TomZetaOfficeState.processGone,
      ms: 30000,
    );
    final noticedMs = _ms(_now - t0);
    final message = find
        .byKey(const ValueKey('zeta-process-gone'))
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .firstOrNull;
    await c.reload();
    final reopened = await _within(
      tester,
      () => c.state == TomZetaOfficeState.open,
      ms: _frames == true ? 200000 : 60000,
    );
    out['web_content_process_killed'] = {
      'killed_processes': victims,
      'killed_by':
          'SIGKILL to the webview\'s web content process (as the '
          'system ends one under memory pressure)',
      'forge_running': true,
      'tab_noticed': noticed,
      'noticed_ms': noticed ? noticedMs : null,
      'tab_message': message,
      'other_tab_unaffected': other.state == TomOfficeEditorState.open,
      'lost': listEquals(before, File(path).readAsBytesSync())
          ? 'the unsaved edit (the file on disk unchanged)'
          : 'the file on disk changed',
      'reopens': reopened,
    };
    await other.close();
    other.dispose();
    final damaged = <String, Object?>{};
    for (final name in evalDamagedFiles) {
      final ms = await open(
        EvalConfig.copy(name, 'zeta-damaged'),
        seconds: 200,
      );
      damaged[name] = {
        'forge_running': true,
        'state': c.state.name,
        'opened': ms != null,
        'tab_message': ?c.error,
      };
    }
    out['damaged_files'] = damaged;
    out['encrypted'] = notMeasured(
      'the sample set has no password-protected office file',
    );
    await _close();
    return out;
  }

  Future<Object?> _features() async {
    await open(EvalConfig.copy('report.docx', 'zeta-features'));
    bool? typed;
    if (await _pageHasFrames()) {
      final before = await c.readForTest();
      await page('keys', _keysScript(5));
      typed = (await c.readForTest()) != before;
    }
    await _close();
    const own = 'present (ZetaOffice\'s own full interface)';
    return {
      for (final f in [
        'styles',
        'find and replace',
        'tables',
        'images',
        'comments',
        'tracked changes',
        'formula bar',
        'sheet tabs',
        'slide sorter and notes',
        'spelling',
      ])
        f: own,
      'printing': 'missing (no print path from the webview to macOS)',
      'inside a Forge tab': {
        'text input (key events reach the document)': typed == null
            ? 'not checked: $_noFramesReason'
            : typed
            ? 'works (synthetic key events typed into the document)'
            : 'not shown by synthetic key events; checked by a person',
        'shortcuts': 'checked by a person (WebKit gets the keys first)',
        'focus': 'checked by a person',
      },
    };
  }

  Future<Object?> _engineChecks() async {
    await open(EvalConfig.copy('report.docx', 'zeta-engine'));
    final checks = <String, Object?>{};
    void check(String what, Object? fake, Object? real) => checks[what] = {
      'fake': fake,
      'zetaoffice': real,
      'matches': fake == real,
    };
    check('clean after open', false, c.isDirty);
    check('nothing to undo after open', false, c.canUndo);
    await c.editForTest('a');
    await _within(tester, () => c.canUndo && c.isDirty, ms: 10000);
    check('an edit: dirty', true, c.isDirty);
    check('an edit: undo enabled', true, c.canUndo);
    await c.undo();
    await _within(tester, () => c.canRedo, ms: 10000);
    check('undo: redo enabled', true, c.canRedo);
    // The modified flag comes in its own callback, after the history's: give
    // it time to arrive before reading it (it stays set if the engine keeps
    // it).
    await _within(tester, () => !c.isDirty, ms: 3000);
    check(
      'undo back to the saved state: clean (the modified flag follows it)',
      false,
      c.isDirty,
    );
    await c.editForTest('b');
    await _within(tester, () => !c.canRedo, ms: 10000);
    check('a new edit after undo ends the redo', false, c.canRedo);
    await c.save();
    await _within(tester, () => !c.isDirty, ms: 10000);
    check('a save clears dirty', false, c.isDirty);
    await _close();
    return {
      'checks': checks,
      'mismatches': [
        for (final e in checks.entries)
          if ((e.value! as Map)['matches'] != true) e.key,
      ],
      'edited_by': 'UNO insertString through the page (the fake: typing)',
    };
  }
}
