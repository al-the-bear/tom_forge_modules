/// A document provider for the Markdown editor (`tom_md_editor`) that edits a
/// document on a web server: [HttpDocumentProvider] opens it with `GET <url>`
/// and saves it with `PUT <url>`, with optional headers such as an
/// `Authorization` token.
///
/// The entry point is the provider itself: hand it to the editor in place of
/// a file or string provider (`MdEditor(documentProvider: HttpDocumentProvider(url: ...))`).
library;

export 'src/http_document_provider.dart';
