/// Output channel management for module logging.
abstract class ForgeOutputChannelManager {
  ForgeOutputChannel create(String name);
  ForgeOutputChannel? get(String name);
  List<ForgeOutputChannel> get channels;
}

/// A named output channel for appending text.
abstract class ForgeOutputChannel {
  String get name;
  void append(String text);
  void appendLine(String line);
  void clear();
  void show({bool preserveFocus = true});
  void hide();
  void dispose();
}
