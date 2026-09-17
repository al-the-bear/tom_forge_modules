/// Does this package compile for the web? D3 §5 says it must; D33 §3.6 makes
/// that an obligation to *measure* rather than to assume.
///
/// The probe is shared (`package:tom_web_build_probe`) rather than copied.
/// `tom_dart_editor` had the only one for a while, and by the second editor a
/// copy would have been a second implementation of the same minute-long build,
/// with its own skip reasons to drift.
library;

import 'package:tom_web_build_probe/tom_web_build_probe.dart';

void main() => registerWebBuildTest(
      id: 'WONECODEPRPC18-flow_editor',
      appDirectory: '../tom_flow_editor_test',
    );
