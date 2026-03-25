import 'forge_disposable.dart';

/// Provides content for virtual document URIs.
abstract class ForgeVirtualDocumentProvider {
  Future<String> provideContent(Uri uri);
  Stream<Uri> get onDidChange;
}

/// Registry for virtual document content providers.
abstract class ForgeVirtualDocumentManager {
  ForgeDisposable registerProvider(
    String scheme,
    ForgeVirtualDocumentProvider provider,
  );
}
