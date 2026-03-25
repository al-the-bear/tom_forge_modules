import 'dart:async';

import '../services/forge_output_channel_manager.dart';

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

/// Default in-memory output channel.
class DefaultOutputChannel implements ForgeOutputChannel {
  @override
  final String name;

  final StringBuffer _buffer = StringBuffer();
  bool _isVisible = false;

  final StreamController<String> _lineController =
      StreamController<String>.broadcast();

  DefaultOutputChannel(this.name);

  @override
  void append(String text) {
    _buffer.write(text);
    _lineController.add(text);
  }

  @override
  void appendLine(String line) {
    _buffer.writeln(line);
    _lineController.add(line);
  }

  @override
  void clear() {
    _buffer.clear();
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

  /// Current channel contents.
  String get contents => _buffer.toString();

  /// Whether the channel is visible.
  bool get isVisible => _isVisible;

  /// Stream of appended lines.
  Stream<String> get onDidAppend => _lineController.stream;
}
