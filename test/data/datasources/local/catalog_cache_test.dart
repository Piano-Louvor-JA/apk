library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';

void main() {
  late Directory tempDir;
  late CatalogCache cache;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cache_test');
    cache = CatalogCache(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('write + read round-trip', () {
    cache.write('categories', [
      {'id': 1, 'name': 'Teste'},
    ]);
    final result = cache.read('categories');
    expect(result, isA<List>());
    expect(result[0]['name'], 'Teste');
  });

  test('read retorna null se nao existe', () {
    expect(cache.read('inexistente'), isNull);
  });

  test('read retorna null se expirado', () {
    cache.write('hymnal', {'data': 'old'});

    // Recria com now no futuro
    final future = DateTime.now().add(const Duration(hours: 25));
    final expiredCache = CatalogCache(tempDir, now: () => future);
    expect(expiredCache.read('hymnal'), isNull);
  });

  test('read funciona dentro do TTL', () {
    cache.write('hymnal', {'data': 'fresh'});

    final nearFuture = DateTime.now().add(const Duration(hours: 12));
    final freshCache = CatalogCache(tempDir, now: () => nearFuture);
    final result = freshCache.read('hymnal');
    expect(result['data'], 'fresh');
  });

  test('evict remove entrada', () {
    cache.write('test', {'v': 1});
    expect(cache.read('test'), isNotNull);
    cache.evict('test');
    expect(cache.read('test'), isNull);
  });

  test('clear remove todas entradas catalog_', () {
    cache.write('a', {'v': 1});
    cache.write('b', {'v': 2});
    cache.clear();
    expect(cache.read('a'), isNull);
    expect(cache.read('b'), isNull);
  });

  test('write cria diretorio se nao existe', () {
    final subdir = Directory('${tempDir.path}/sub');
    final subCache = CatalogCache(subdir);
    subCache.write('x', {'v': 1});
    expect(subCache.read('x'), isNotNull);
  });

  test('read com JSON corrompido retorna null', () {
    final f = File('${tempDir.path}/catalog_corrupt.json');
    f.writeAsStringSync('nao é json {{{');
    expect(cache.read('corrupt'), isNull);
  });

  test('evict de chave inexistente nao quebra', () {
    cache.evict('nao_existe');
  });
}
