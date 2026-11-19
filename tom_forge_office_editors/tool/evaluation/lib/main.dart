// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// The office routes' evaluation harness as an app: the host, a recording
/// helper launcher and the two views the integration test
/// (`integration_test/office_routes_test.dart`) pumps. Run it through
/// `run_evaluation.py`, not on its own.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_file_session/io.dart';
import 'package:tom_office_editor/io.dart';
import 'package:tom_office_editor/tom_office_editor.dart';
import 'package:tom_office_editor/zetaoffice.dart';
import 'package:tom_office_protocol/tom_office_protocol.dart';

/// One timestamped message between the editor and its helper: what the
/// `[OE]` trail logs (`-> key`, `-> renderTile`, `<- callback`, the tiles),
/// with a monotonic time in microseconds.
typedef EvalHelperEvent = ({int us, bool sent, Object message});

/// The monotonic clock every timestamp of the harness uses.
final Stopwatch evalClock = Stopwatch()..start();

/// A helper channel that records every message with its time (the latency
/// breakdown: key sent, LibreOffice's first callback, tile requested, tile
/// received).
class RecordingHelperChannel implements TomOfficeHelperChannel {
  RecordingHelperChannel(this.inner) {
    _events = inner.events.map((e) {
      record.add((us: evalClock.elapsedMicroseconds, sent: false, message: e));
      if (e is OfficeHello) helperPid = e.pid;
      return e;
    }).asBroadcastStream();
  }

  /// The real channel.
  final TomOfficeHelperChannel inner;

  /// Every message, in order.
  final record = <EvalHelperEvent>[];

  /// The helper's process id (from its `hello`).
  int? helperPid;

  late final Stream<OfficeHelperEvent> _events;

  @override
  Stream<OfficeHelperEvent> get events => _events;

  @override
  Stream<String> get log => inner.log;

  @override
  Future<TomOfficeHelperExit> get exit => inner.exit;

  @override
  void send(OfficeHelperCommand command) {
    record.add((us: evalClock.elapsedMicroseconds, sent: true, message: command));
    inner.send(command);
  }

  @override
  Future<TomOfficeHelperExit> close() => inner.close();

  @override
  void kill() => inner.kill();
}

/// The binaries layer's helper for the installed LibreOffice, every channel
/// recorded.
class RecordingLauncher implements TomOfficeHelperLauncher {
  RecordingLauncher(this.installation)
    : _inner = TomOfficeProcessLauncher(
        installation: installation,
        helperExecutable: TomOfficeProcessLauncher.findHelper() ?? '',
      );

  @override
  final LibreOfficeInstallation installation;

  final TomOfficeProcessLauncher _inner;

  /// Every channel started, in order.
  final channels = <RecordingHelperChannel>[];

  @override
  Future<TomOfficeHelperChannel> start({required String documentPath}) async {
    final channel = RecordingHelperChannel(
      await _inner.start(documentPath: documentPath),
    );
    channels.add(channel);
    return channel;
  }
}

/// A desktop host as Forge's `ForgeOfficeHost` gives the editors: local
/// files, the recording launcher; notices kept for the results.
class EvalOfficeHost implements TomOfficeEditorHost {
  EvalOfficeHost(this.filePath, this.helper);

  @override
  final String filePath;

  @override
  final RecordingLauncher helper;

  /// The notices the editor gave, as `kind: message`.
  final notices = <String>[];

  @override
  String get name => filePath.split('/').last;

  @override
  TomBinaryFiles get files => const TomBinaryFileAccess();

  @override
  void notice(BuildContext context, String message, {required String kind}) =>
      notices.add('$kind: $message');

  @override
  void openLink(String url) {}

  @override
  void historyChanged() {}

  @override
  Future<String?> pickImage() async => null;
}

/// The key of the boundary the LibreOfficeKit view is captured from.
final lokViewKey = GlobalKey();

/// The LibreOfficeKit editors, as Forge tabs show them: the first one
/// visible, the others kept in the tree (one helper per document).
class LokEvalApp extends StatelessWidget {
  const LokEvalApp({super.key, required this.controllers});

  final List<TomOfficeEditorController> controllers;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: lokViewKey,
              child: TomOfficeEditor(
                key: ValueKey(controllers.first),
                controller: controllers.first,
              ),
            ),
          ),
          for (final c in controllers.skip(1))
            SizedBox(
              height: 1,
              child: TomOfficeEditor(
                key: ValueKey(c),
                controller: c,
                showRibbon: false,
              ),
            ),
        ],
      ),
    ),
  );
}

/// ZetaOffice in the webview, as a Forge tab shows it.
class ZetaEvalApp extends StatelessWidget {
  const ZetaEvalApp({super.key, required this.controller});

  final TomZetaOfficeController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: TomZetaOfficeView(key: ValueKey(controller), controller: controller),
    ),
  );
}

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Run integration_test/office_routes_test.dart through '
            'run_evaluation.py.',
          ),
        ),
      ),
    ),
  );
}
