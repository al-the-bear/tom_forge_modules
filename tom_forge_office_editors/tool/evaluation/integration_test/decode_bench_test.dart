// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// Where a LibreOfficeKit tile's decode time goes (officeproto31hf): a tile
/// is 512 × 512 BGRA (1 MB) at device pixel ratio 2. Three ways to turn the
/// helper's pixels into an image —
///
/// - `decodeImageFromPixels` (what the editor used): an `ImmutableBuffer`, an
///   `ImageDescriptor.raw`, a codec and its first frame, each a hop;
/// - `ImageDescriptor.raw` with `instantiateCodec`, called directly;
/// - `decodeImageFromPixelsSync`: an image at once, drawable while it
///   finishes —
///
/// each for one tile alone and for 20 at once (a repaint), with frames
/// running and with the app idle (does a completion wait for a frame?), and
/// the synchronous image drawn back to check it holds the pixels. Writes
/// `$EVAL_RESULTS/decode-bench.yaml`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tom_forge_office_route_evaluation/eval_support.dart';

const _side = 512;

/// A text-like tile: white with dark strokes, as LibreOffice paints a page.
Uint8List _tile(int seed) {
  final b = Uint8List(_side * _side * 4);
  for (var i = 0; i < b.length; i += 4) {
    final row = (i ~/ 4) ~/ _side;
    final col = (i ~/ 4) % _side;
    final ink = row % 18 < 3 && (col + seed) % 9 < 6;
    final v = ink ? 30 : 255;
    b[i] = v; // B
    b[i + 1] = v; // G
    b[i + 2] = v; // R
    b[i + 3] = 255; // A
  }
  return b;
}

Future<ui.Image> _viaDecodeImageFromPixels(Uint8List px) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    px,
    _side,
    _side,
    ui.PixelFormat.bgra8888,
    c.complete,
  );
  return c.future;
}

Future<ui.Image> _viaDescriptor(Uint8List px) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(px);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: _side,
    height: _side,
    pixelFormat: ui.PixelFormat.bgra8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}

Future<ui.Image> _viaSync(Uint8List px) async =>
    ui.decodeImageFromPixelsSync(px, _side, _side, ui.PixelFormat.bgra8888);

typedef _Way = Future<ui.Image> Function(Uint8List);

Map<String, num> _stats(List<double> ms) {
  final s = [...ms]..sort();
  double at(double q) => s[((s.length - 1) * q).round()];
  return {
    'count': s.length,
    'median_ms': double.parse(at(0.5).toStringAsFixed(2)),
    'p95_ms': double.parse(at(0.95).toStringAsFixed(2)),
    'max_ms': double.parse(s.last.toStringAsFixed(2)),
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DECODE-BENCH: where a tile\'s decode time goes', (tester) async {
    final out = <String, Object?>{
      'environment': environmentInfo(),
      'tile': '$_side x $_side BGRA (${_side * _side * 4} bytes)',
    };
    final tiles = [for (var i = 0; i < 20; i++) _tile(i)];
    final ways = <String, _Way>{
      'decodeImageFromPixels': _viaDecodeImageFromPixels,
      'ImageDescriptor.raw + instantiateCodec': _viaDescriptor,
      'decodeImageFromPixelsSync': _viaSync,
    };

    // Frames running (the live policy pumps them) or idle (none asked for).
    Future<T> withFrames<T>(bool frames, Future<T> Function() body) async {
      if (!frames) return tester.runAsync(body).then((v) => v as T);
      final policy = binding.framePolicy;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      var done = false;
      late T value;
      unawaited(
        tester.runAsync(body).then((v) {
          value = v as T;
          done = true;
        }),
      );
      while (!done) {
        SchedulerBinding.instance.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 4));
      }
      binding.framePolicy = policy;
      return value;
    }

    for (final frames in [false, true]) {
      final label = frames ? 'frames running' : 'app idle';
      final section = <String, Object?>{};
      for (final MapEntry(key: name, value: way) in ways.entries) {
        // Warm-up, then one tile at a time.
        (await withFrames(frames, () => way(tiles[0]))).dispose();
        final alone = <double>[];
        for (var r = 0; r < 30; r++) {
          final ms = await withFrames(frames, () async {
            final w = Stopwatch()..start();
            final image = await way(tiles[r % tiles.length]);
            final t = w.elapsedMicroseconds / 1000;
            image.dispose();
            return t;
          });
          alone.add(ms);
        }
        // 20 at once, as a repaint asks for them: when the first and the
        // last are ready.
        final first = <double>[], last = <double>[];
        for (var r = 0; r < 10; r++) {
          final (f, l) = await withFrames(frames, () async {
            final w = Stopwatch()..start();
            double? firstMs;
            final images = await Future.wait([
              for (final px in tiles)
                way(px).then((i) {
                  firstMs ??= w.elapsedMicroseconds / 1000;
                  return i;
                }),
            ]);
            final lastMs = w.elapsedMicroseconds / 1000;
            for (final i in images) {
              i.dispose();
            }
            return (firstMs!, lastMs);
          });
          first.add(f);
          last.add(l);
        }
        section[name] = {
          'one_tile': _stats(alone),
          'twenty_at_once_first_ready': _stats(first),
          'twenty_at_once_all_ready': _stats(last),
        };
      }
      out[label] = section;
    }

    // The synchronous image drawn back: does it hold the pixels at once?
    out['sync_image_drawn_back'] = await tester.runAsync(() async {
      final px = _tile(3);
      final image = ui.decodeImageFromPixelsSync(
        px,
        _side,
        _side,
        ui.PixelFormat.bgra8888,
      );
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImage(image, ui.Offset.zero, ui.Paint());
      final drawn = await recorder.endRecording().toImage(_side, _side);
      final bytes = (await drawn.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var differing = 0;
      for (var i = 0; i < bytes.length; i += 4) {
        // RGBA back against the BGRA given.
        if (bytes[i] != px[i + 2] ||
            bytes[i + 1] != px[i + 1] ||
            bytes[i + 2] != px[i]) {
          differing++;
        }
      }
      image.dispose();
      drawn.dispose();
      return {'pixels_compared': _side * _side, 'pixels_differing': differing};
    });

    final dir = Directory(EvalConfig.results)..createSync(recursive: true);
    File('${dir.path}/decode-bench.yaml').writeAsStringSync(
      '# Tile decode benchmark (officeproto31hf), '
      'integration_test/decode_bench_test.dart.\n${toYaml(out)}',
    );
    print('[eval] wrote ${dir.path}/decode-bench.yaml');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
