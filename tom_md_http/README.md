# Tom Markdown HTTP

Lets the Markdown editor (`tom_md_editor`) edit a document that lives on a web
server instead of in a file. One class, `HttpDocumentProvider`, and its one
dependency, `http`.

```dart
import 'package:tom_md_http/tom_md_http.dart';

MdEditor(
  documentProvider: HttpDocumentProvider(
    url: 'https://docs.example.com/api/readme',
    headers: {'Authorization': 'Bearer $token'},
  ),
);
```

- **Open** sends `GET <url>` and shows the body; on a status other than 200,
  or a network error, it logs the reason and shows an empty document.
- **Save** sends `PUT <url>` with the Markdown as the body
  (`Content-Type: text/markdown`); a failed save throws `HttpException`.
- The title is the URL's last path segment; saving is always allowed; there
  is no live reload, so a change made on the server is seen when the
  document is opened again.

It does no conflict detection (the last `PUT` wins), no retry, no
authentication flow (the caller supplies the header) and no listing of
documents: it suits a simple REST endpoint for one document.

## License

BSD-3-Clause — see [LICENSE](LICENSE).
