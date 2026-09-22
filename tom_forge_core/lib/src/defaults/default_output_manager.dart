import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Default implementation of [ForgeOutputChannelManager].
///
/// Creates in-memory output channels for module logging.
class DefaultOutputChannelManager implements ForgeOutputChannelManager {
  static bool debugEnabled = false;

  final Map<String, DefaultOutputChannel> _channels = {};

  @override
  ForgeOutputChannel create(String name) {
    if (_channels.containsKey(name)) {
      return _channels[name]!;
    }
    final channel = DefaultOutputChannel(name);
    _channels[name] = channel;
    return channel;
  }

  @override
  ForgeOutputChannel? get(String name) => _channels[name];

  @override
  List<ForgeOutputChannel> get channels =>
      List.unmodifiable(_channels.values);

  /// Dispose all channels.
  void dispose() {
    for (final channel in _channels.values) {
      channel.dispose();
    }
    _channels.clear();
  }
}

/// Default in-memory output channel with ring-buffer line limits.
class DefaultOutputChannel implements ForgeOutputChannel {
  @override
  final String name;

  /// Maximum number of lines retained. Oldest lines are discarded first.
  final int maxLines;

  final List<OutputLine> _lines = [];
  bool _isVisible = false;

  final StreamController<String> _lineController =
      StreamController<String>.broadcast();

  DefaultOutputChannel(this.name, {this.maxLines = 1000});

  @override
  void append(String text, {OutputMessageType type = OutputMessageType.info}) {
    _addLine(text, newline: false, type: type);
    _lineController.add(text);
  }

  @override
  void appendLine(String line, {OutputMessageType type = OutputMessageType.info}) {
    _addLine(line, newline: true, type: type);
    _lineController.add(line);
  }

  void _addLine(
    String text, {
    required bool newline,
    OutputMessageType type = OutputMessageType.info,
  }) {
    _lines.add(OutputLine(
      text: text,
      timestamp: DateTime.now(),
      hasNewline: newline,
      type: type,
    ));
    // Enforce ring buffer limit.
    while (_lines.length > maxLines) {
      _lines.removeAt(0);
    }
  }

  @override
  void clear() {
    _lines.clear();
  }

  @override
  void show({bool preserveFocus = true}) {
    _isVisible = true;
  }

  @override
  void hide() {
    _isVisible = false;
  }

  @override
  void dispose() {
    _lineController.close();
  }

  /// All stored output lines.
  List<OutputLine> get lines => List.unmodifiable(_lines);

  /// Current channel contents, one line per appended entry, in the uniform
  /// format `[HH:MM:SS] [TYPE] text`.
  ///
  /// The timestamp and the type are **unconditional**. There is deliberately no
  /// second, plainer spelling: the view that used to offer a timestamp toggle
  /// no longer does, and a getter named for the distinction would imply this
  /// one lacks what it in fact always includes.
  String get contents {
    final buf = StringBuffer();
    for (final line in _lines) {
      final ts = _formatTimestamp(line.timestamp);
      final formatted = '[$ts] [${line.type.label}] ${line.text}';
      if (line.hasNewline) {
        buf.writeln(formatted);
      } else {
        buf.write(formatted);
      }
    }
    return buf.toString();
  }

  static String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Whether the channel is visible.
  bool get isVisible => _isVisible;

  /// Stream of appended lines.
  Stream<String> get onDidAppend => _lineController.stream;
}

/// A single output line with metadata.
class OutputLine {
  final String text;
  final DateTime timestamp;
  final bool hasNewline;
  final OutputMessageType type;

  const OutputLine({
    required this.text,
    required this.timestamp,
    this.hasNewline = true,
    this.type = OutputMessageType.info,
  });
}
