import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';

/// Moderação da Comunidade (App Store 1.2): denunciar, bloquear, listar e
/// desbloquear autores — contrato com a API /v1/custom.
class _Call {
  final String method;
  final String url;
  final Map<String, dynamic>? body;
  final String? bearerToken;
  _Call(this.method, this.url, this.body, this.bearerToken);
}

void main() {
  late List<_Call> calls;
  late CustomCatalogApiImpl api;
  late Object? Function(String method, String url) responder;

  setUp(() {
    calls = [];
    responder = (_, _) => <String, dynamic>{};
    api = CustomCatalogApiImpl(
      fetch: (method, url, {body, bearerToken}) async {
        calls.add(_Call(method, url, body, bearerToken));
        return responder(method, url);
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );
  });

  test('reportCollection: POST /collections/{id}/report com motivo', () async {
    await api.reportCollection(7, reason: 'Spam', bearerToken: 'tok');
    final c = calls.single;
    expect(c.method, 'POST');
    expect(c.url, 'https://api.test/v1/custom/collections/7/report');
    expect(c.body, {'reason': 'Spam'});
    expect(c.bearerToken, 'tok');
  });

  test('blockAuthor: POST /collections/{id}/block-author → autor', () async {
    responder = (_, _) => {
      'blocked': {'id_user': 9, 'displayName': 'Beto'},
    };
    final author = await api.blockAuthor(7, bearerToken: 'tok');
    expect(calls.single.method, 'POST');
    expect(
      calls.single.url,
      'https://api.test/v1/custom/collections/7/block-author',
    );
    expect(author.id, 9);
    expect(author.name, 'Beto');
  });

  test('fetchBlockedAuthors: GET /blocks (JSON em string também)', () async {
    responder = (_, _) =>
        '{"data":[{"id_user":9,"displayName":"Beto"},{"id_user":3,"displayName":null}]}';
    final list = await api.fetchBlockedAuthors(bearerToken: 'tok');
    expect(calls.single.method, 'GET');
    expect(calls.single.url, 'https://api.test/v1/custom/blocks');
    expect(list.map((a) => a.id), [9, 3]);
    expect(list.last.name, 'Autor sem nome');
  });

  test('fetchBlockedAuthors: resposta vazia → lista vazia', () async {
    responder = (_, _) => '';
    expect(await api.fetchBlockedAuthors(bearerToken: 'tok'), isEmpty);
  });

  test('unblockAuthor: DELETE /blocks/{id}', () async {
    await api.unblockAuthor(9, bearerToken: 'tok');
    expect(calls.single.method, 'DELETE');
    expect(calls.single.url, 'https://api.test/v1/custom/blocks/9');
    expect(calls.single.bearerToken, 'tok');
  });
}
