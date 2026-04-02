/// Output channel management for module logging.
abstract class ForgeOutputChannelManager {
  ForgeOutputChannel create(String name);
  ForgeOutputChannel? get(String name);
  List<ForgeOutputChannel> get channels;
}

/// A named output channel for appending text.
abstract class ForgeOutputChannel {
  String get name;
  void append(String text, {OutputMessageType type});
  void appendLine(String line, {OutputMessageType type});
  void clear();
  void show({bool preserveFocus = true});
  void hide();
  void dispose();
}

/// Message severity for output channel lines.
enum OutputMessageType {
  info('INFO'),
  warn('WARN'),
  error('ERROR'),
  debug('DEBUG');

  final String label;
  const OutputMessageType(this.label);
}
