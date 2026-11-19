import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

/// Platform keychain-backed implementation of [ForgeSecretStorage].
///
/// Uses [FlutterSecureStorage] which delegates to:
/// - **macOS/iOS**: Keychain Services
/// - **Linux**: libsecret
/// - **Windows**: Windows Credential Manager
/// - **Web**: encrypted localStorage
///
/// All keys are prefixed with `forge_` to namespace Forge secrets within
/// the shared platform keychain.
class PlatformSecretStorage implements ForgeSecretStorage {
  static const _prefix = 'forge_';

  final FlutterSecureStorage _storage;
  final StreamController<SecretChangeEvent> _changeController =
      StreamController<SecretChangeEvent>.broadcast();

  PlatformSecretStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  String _prefixed(String key) => '$_prefix$key';

  @override
  Future<void> store(String key, String value) async {
    try {
      await _storage.write(key: _prefixed(key), value: value);
      _changeController.add(SecretChangeEvent(key: key, deleted: false));
    } catch (e) {
      debugPrint('[PlatformSecretStorage] store failed for "$key": $e');
      rethrow;
    }
  }

  @override
  Future<String?> get(String key) async {
    try {
      return await _storage.read(key: _prefixed(key));
    } catch (e) {
      debugPrint('[PlatformSecretStorage] get failed for "$key": $e');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: _prefixed(key));
      _changeController.add(SecretChangeEvent(key: key, deleted: true));
    } catch (e) {
      debugPrint('[PlatformSecretStorage] delete failed for "$key": $e');
      rethrow;
    }
  }

  @override
  Stream<SecretChangeEvent> get onDidChange => _changeController.stream;

  /// Dispose resources.
  void dispose() {
    _changeController.close();
  }
}
