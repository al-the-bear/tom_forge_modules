import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_terminal_view/tom_terminal_view.dart';

/// A [TomTerminalProcess] a test drives: [emit] is what the process writes,
/// [written] what the session sent it, [exit] ends it.
class FakeTerminalProcess implements TomTerminalProcess {
  FakeTerminalProcess(this.options);

  /// What the session started it with.
  final TomTerminalOptions options;

  final StreamController<Uint8List> _output = StreamController<Uint8List>();
  final Completer<int> _exit = Completer<int>();

  /// Everything the session wrote, decoded.
  final List<String> written = [];

  /// Every resize, as (rows, columns).
  final List<(int, int)> resizes = [];

  /// How often [kill] was called.
  int kills = 0;

  /// Makes the process write [text].
  void emit(String text) => _output.add(Uint8List.fromList(utf8.encode(text)));

  /// Ends the process with [code].
  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => 4242;

  @override
  void write(Uint8List data) => written.add(utf8.decode(data));

  @override
  void resize(int rows, int columns) => resizes.add((rows, columns));

  @override
  bool kill() {
    kills++;
    exit(-15);
    return true;
  }
}
