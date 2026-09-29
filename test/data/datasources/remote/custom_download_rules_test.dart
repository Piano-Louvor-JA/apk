import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';

/// Integração: join/leave de coletâneas (download/remoção de download) —
/// persistem em SharedPreferences e se anulam mutuamente.
void main() {
  const collection = CustomCollection(
    id: 42,
    name: 'Comunidade',
    musicsCount: 3,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('joinCollection / leaveCollection (download)', () {
    test('join marca como baixada; fetchJoinedCollectionIds reflete', () async {
      final api = _api();
      await api.joinCollection(collection);
      expect(await api.fetchJoinedCollectionIds(), {42});
    });

    test(
      'leave desmarca; check duplo = remover download (undo do join)',
      () async {
        final api = _api();
        await api.joinCollection(collection);
        await api.leaveCollection(collection);
        expect(await api.fetchJoinedCollectionIds(), isEmpty);
      },
    );

    test('leave sem join prévio não falha (idempotente)', () async {
      final api = _api();
      await api.leaveCollection(collection);
      expect(await api.fetchJoinedCollectionIds(), isEmpty);
    });

    test('join é idempotente (duas vezes = uma marca)', () async {
      final api = _api();
      await api.joinCollection(collection);
      await api.joinCollection(collection);
      expect(await api.fetchJoinedCollectionIds(), {42});
    });

    test('coletâneas distintas mantêm estado independente', () async {
      final api = _api();
      const other = CustomCollection(id: 7, name: 'Outra', musicsCount: 1);
      await api.joinCollection(collection);
      await api.joinCollection(other);
      await api.leaveCollection(collection);
      expect(await api.fetchJoinedCollectionIds(), {7});
    });
  });
}

CustomCatalogApiImpl _api() => CustomCatalogApiImpl(
  fetch: (method, url, {body, bearerToken}) async => <String, dynamic>{},
  apiBaseUrl: 'https://api.test',
  filesBaseUrl: 'https://api.test/file',
);
