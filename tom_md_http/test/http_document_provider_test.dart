import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tom_md_http/tom_md_http.dart';

void main() {
  group('HttpDocumentProvider', () {
    const url = 'https://docs.example.com/api/readme';

    test(
      'HTTP-1: load sends GET with the headers and shows the body',
      () async {
        late http.Request seen;
        final client = MockClient((request) async {
          seen = request;
          return http.Response('# Readme\n', 200);
        });
        final provider = HttpDocumentProvider(
          url: url,
          headers: {'Authorization': 'Bearer token'},
        );
        final text = await http.runWithClient(provider.load, () => client);
        expect(text, '# Readme\n');
        expect(seen.method, 'GET');
        expect(seen.url.toString(), url);
        expect(seen.headers['Authorization'], 'Bearer token');
      },
    );

    test('HTTP-2: a status other than 200 shows an empty document', () async {
      final client = MockClient((_) async => http.Response('missing', 404));
      final provider = HttpDocumentProvider(url: url);
      expect(await http.runWithClient(provider.load, () => client), '');
    });

    test('HTTP-3: save sends PUT with the Markdown as the body', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('', 204);
      });
      final provider = HttpDocumentProvider(
        url: url,
        headers: {'Authorization': 'Bearer token'},
      );
      await http.runWithClient(() => provider.save('# New\n'), () => client);
      expect(seen.method, 'PUT');
      expect(seen.body, '# New\n');
      expect(seen.headers['Content-Type'], startsWith('text/markdown'));
      expect(seen.headers['Authorization'], 'Bearer token');
    });

    test('HTTP-4: a failed save throws an HttpException', () async {
      final client = MockClient((_) async => http.Response('no', 500));
      final provider = HttpDocumentProvider(url: url);
      await expectLater(
        http.runWithClient(() => provider.save('x'), () => client),
        throwsA(isA<HttpException>()),
      );
    });

    test('HTTP-5: the title is the last path segment; saving is allowed', () {
      final provider = HttpDocumentProvider(url: url);
      expect(provider.metadata.title, 'readme');
      expect(provider.metadata.path, url);
      expect(provider.canSave, isTrue);
      expect(provider.externalChanges, isNull);
    });
  });
}
