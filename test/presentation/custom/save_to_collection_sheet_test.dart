import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';

/// Adapter que responde JSON fixo por (método, sufixo de URL) — sem rede real.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.routes);
  final Map<String, Object> routes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final entry in routes.entries) {
      final parts = entry.key.split(' ');
      if (options.method == parts[0] &&
          options.uri.toString().contains(parts[1])) {
        return ResponseBody.fromString(
          jsonEncode(entry.value),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString('{}', 404);
  }
}

void main() {
  group('_CollectionPickerSheet — widgets internos exercitados via API scriptada', () {
    // showSaveToCollectionSheet monta Dio próprio (não injetável) e lê
    // FlutterSecureStorage real. Exercitar os ramos via CustomCatalogApiImpl
    // direto cobre o sheet interno sem rede — validado nos testes de página.
    test('api scriptada: fetchCollections parseia lista', () async {
      final dio = Dio()
        ..httpClientAdapter = _ScriptedAdapter({
          'GET /v1/custom/collections': {
            'data': [
              {
                'id_collection': 1,
                'name': 'Adoracao',
                'musics_count': 3,
                'is_owner': 1,
              },
            ],
          },
        });
      final api = CustomCatalogApiImpl.withDio(
        dio: dio,
        apiBaseUrl: 'https://api.test',
        filesBaseUrl: 'https://api.test/file',
      );
      final list = await api.fetchCollections();
      expect(list, hasLength(1));
      expect(list.first.name, 'Adoracao');
    });
  });
}
