/// Clipboard access for the forge shell.
abstract class ForgeClipboard {
  Future<String> readText();
  Future<void> writeText(String text);
}
