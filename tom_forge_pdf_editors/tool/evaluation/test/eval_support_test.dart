/// The harness's frame statistics.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_pdf_route_evaluation/eval_support.dart';

void main() {
  test('EVS-1: page frame intervals in whole milliseconds: on-time 60 Hz '
      'frames (16 and 17 ms) are no jank, a missed frame is', () {
    final stats = intervalStats([16, 17, 17, 16, 17, 34, 17, 16, 50, 17]);
    expect(stats['frames'], 10);
    expect(stats['jank_threshold_ms'], kPageJankThresholdMs);
    expect(stats['jank_share'], 0.2);
    expect(intervalStats([25, 26])['jank_share'], 0.5);
  });
}
