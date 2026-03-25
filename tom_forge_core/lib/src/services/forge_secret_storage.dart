import 'package:tom_forge_core/tom_forge_core.dart';

/// Secure storage for tokens, API keys, and other secrets.
abstract class ForgeSecretStorage {
  Future<void> store(String key, String value);
  Future<String?> get(String key);
  Future<void> delete(String key);
  Stream<SecretChangeEvent> get onDidChange;
}
