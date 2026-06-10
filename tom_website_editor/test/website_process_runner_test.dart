// DartIoWebsiteProcessRunner real-process behaviour (§5, §7).
//
// The control panel runs commands through `bash -lc`; long-lived commands
// (serveStart/build) spawn a grandchild daemon. A plain kill of the bash parent
// orphans that grandchild, which then holds the build lock and makes the next
// `build` fail with "another process is using build_runner". The runner spawns
// the command as a session leader so kill() can terminate the whole process
// group. This test reproduces the orphan scenario with a tagged background
// `sleep` grandchild and asserts the tree is gone after kill().
//
// POSIX-only: the group-kill path uses perl's POSIX::setsid + a negative-pid
// signal, which Windows does not support.
@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

/// Returns `true` while at least one process whose command line contains [tag]
/// is alive (via `pgrep -f`).
Future<bool> _processAlive(String tag) async {
  final result = await Process.run('pgrep', ['-f', tag]);
  return result.exitCode == 0 &&
      (result.stdout as String).trim().isNotEmpty;
}

void main() {
  group('DartIoWebsiteProcessRunner process-group kill', () {
    test(
        'TWE-PROC-01: kill() terminates an orphan-prone grandchild process',
        () async {
      const runner = DartIoWebsiteProcessRunner();
      // Unique tag so pgrep matches only this test's grandchild. `exec -a`
      // rewrites argv[0] so the tag appears in the sleep's command line.
      final tag = 'tom-killtest-${DateTime.now().microsecondsSinceEpoch}';
      // bash backgrounds the tagged sleep (the orphan-prone grandchild), prints
      // READY, then blocks. A plain parent-only kill would leave the sleep
      // running; the group kill must take it down with the shell.
      final command =
          '(exec -a $tag sleep 30) & echo READY; wait';

      final handle = runner.start(WebsiteCommandSpec(
        executable: 'bash',
        arguments: ['-lc', command],
        workingDirectory: Directory.current.path,
        display: command,
      ));

      // Wait until the grandchild has launched.
      await handle.output.firstWhere((line) => line.text.trim() == 'READY');
      // Give the backgrounded process a beat to appear in the process table.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(await _processAlive(tag), isTrue,
          reason: 'grandchild should be running before kill()');

      await handle.kill();
      // Allow the signal to propagate through the group.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(await _processAlive(tag), isFalse,
          reason: 'group kill must terminate the orphan-prone grandchild');

      // Best-effort cleanup if the assertion above ever fails.
      if (await _processAlive(tag)) {
        await Process.run('pkill', ['-f', tag]);
      }
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
