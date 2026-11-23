import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tom_md_editor/tom_md_editor.dart';

/// Document provider that loads/saves markdown via HTTP.
///
/// Uses GET to load and PUT to save.
/// ```dart
/// final provider = HttpDocumentProvider(
///   url: 'https://api.example.com/docs/readme',
///   headers: {'Authorization': 'Bearer token'},
/// );
/// ```
class HttpDocumentProvider implements MdDocumentProvider {
  HttpDocumentProvider({
    required this.url,
    this.headers,
  });

  /// The URL for the markdown document.
  final String url;

  /// Optional HTTP headers (e.g. for authentication).
  final Map<String, String>? headers;

  @override
  MdDocumentMetadata get metadata => MdDocumentMetadata(
        path: url,
        title: Uri.parse(url).pathSegments.lastOrNull ?? 'document',
      );

  @override
  bool get canSave => true;

  @override
  Stream<String>? get externalChanges => null;

  @override
  Future<String> load() async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
      MdEditorDebug.logger.info(
        'HTTP load returned status ${response.statusCode}',
      );
      return '';
    } catch (e, st) {
      MdEditorDebug.logger.error('Error loading from HTTP: $url', e, st);
      return '';
    }
  }

  @override
  Future<void> save(String markdown) async {
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'text/markdown; charset=utf-8',
          ...?headers,
        },
        body: markdown,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP save failed with status ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
    } catch (e, st) {
      MdEditorDebug.logger.error('Error saving to HTTP: $url', e, st);
      rethrow;
    }
  }
}

/// Exception for HTTP errors.
@immutable
class HttpException implements Exception {
  const HttpException(this.message, {this.uri});
  final String message;
  final Uri? uri;
  @override
  String toString() => 'HttpException: $message${uri != null ? ' ($uri)' : ''}';
}
