/// Terminal instance management.
abstract class ForgeTerminalManager {
  ForgeTerminal create({String? name, String? shellPath, String? cwd});
  List<ForgeTerminal> get terminals;
  ForgeTerminal? get activeTerminal;
  Stream<ForgeTerminal> get onDidOpen;
  Stream<ForgeTerminal> get onDidClose;
  Stream<ForgeTerminal?> get onDidChangeActive;
}

/// A terminal instance.
abstract class ForgeTerminal {
  String get name;
  void sendText(String text, {bool addNewLine = true});
  void show({bool preserveFocus = true});
  void dispose();
}
