/// Environment utilities (app identity, external URI opening).
abstract class ForgeEnvironment {
  String get appName;
  Future<void> openExternal(Uri uri);
}
