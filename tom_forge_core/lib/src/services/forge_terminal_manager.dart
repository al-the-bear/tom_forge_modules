import 'forge_output_channel_manager.dart';

/// Terminal instance management.
abstract class ForgeTerminalManager {
  ForgeTerminal create({
    String? name,
    String? shellPath,
    String? cwd,
    ForgeOutputChannel? outputChannel,
  });
  List<ForgeTerminal> get terminals;
  ForgeTerminal? get activeTerminal;

  /// Sets [terminal] as the active terminal.
  void setActive(ForgeTerminal terminal);

  Stream<ForgeTerminal> get onDidOpen;
  Stream<ForgeTerminal> get onDidClose;
  Stream<ForgeTerminal?> get onDidChangeActive;
}

/// A terminal instance.
abstract class ForgeTerminal {
  String get name;

  /// Stream of output lines produced by the terminal.
  Stream<String> get onOutput;

  void sendText(String text, {bool addNewLine = true});
  void show({bool preserveFocus = true});

  /// Close this terminal (removes from manager and disposes resources).
  void close();

  void dispose();
}
