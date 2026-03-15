import 'package:flutter/services.dart';

import '../debug/md_editor_debug.dart';
import 'md_document_provider.dart';

/// Document provider that loads markdown from a Flutter asset bundle.
///
/// This is read-only — [save] will throw [UnsupportedError].
/// ```dart
/// final provider = AssetDocumentProvider(asset: 'assets/docs/guide.md');
/// ```
class AssetDocumentProvider implements MdDocumentProvider {
  AssetDocumentProvider({
    required this.asset,
    AssetBundle? bundle,
  }) : _bundle = bundle;

  /// The asset path (e.g. 'assets/docs/guide.md').
  final String asset;
  final AssetBundle? _bundle;

  AssetBundle get _effectiveBundle => _bundle ?? rootBundle;

  @override
  MdDocumentMetadata get metadata => MdDocumentMetadata(
        path: asset,
        title: asset.split('/').last,
      );

  @override
  bool get canSave => false;

  @override
  Stream<String>? get externalChanges => null;

  @override
  Future<String> load() async {
    try {
      return await _effectiveBundle.loadString(asset);
    } catch (e, st) {
      MdEditorDebug.logger.error('Error loading asset: $asset', e, st);
      return '';
    }
  }

  @override
  Future<void> save(String markdown) async {
    throw UnsupportedError(
      'AssetDocumentProvider is read-only. Cannot save to asset: $asset',
    );
  }
}
