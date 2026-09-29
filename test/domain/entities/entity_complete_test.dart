// ignore_for_file: unrelated_type_equality_checks, unnecessary_null_comparison
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

void main() {
  // ---- Album ----
  test('Album == por id', () {
    const a = Album(id: 1, name: 'A');
    const b = Album(id: 1, name: 'B');
    const c = Album(id: 2, name: 'A');
    expect(a == b, true);
    expect(a == c, false);
  });

  test('Album identical', () {
    const a = Album(id: 1);
    expect(a == a, true);
  });

  test('Album == tipo diferente', () {
    const a = Album(id: 1);
    expect(a == 'str', false);
    expect(a == 42, false);
    expect(a == null, false);
  });

  test('Album hashCode consistente', () {
    const a = Album(id: 1);
    const b = Album(id: 1);
    expect(a.hashCode, b.hashCode);
  });

  test('Album toString', () {
    const a = Album(id: 5, name: 'Teste');
    expect(a.toString(), 'Album(id: 5, name: Teste)');
  });

  // ---- AlbumCategory ----
  test('AlbumCategory == por id', () {
    final a = AlbumCategory(id: 1, name: 'A');
    final b = AlbumCategory(id: 1, name: 'B');
    final c = AlbumCategory(id: 2, name: 'A');
    expect(a == b, true);
    expect(a == c, false);
  });

  test('AlbumCategory identical', () {
    final a = AlbumCategory(id: 1);
    expect(a == a, true);
  });

  test('AlbumCategory == tipo diferente', () {
    final a = AlbumCategory(id: 1);
    expect(a == 'str', false);
    expect(a == 42, false);
    expect(a == null, false);
  });

  test('AlbumCategory hashCode', () {
    final a = AlbumCategory(id: 1);
    final b = AlbumCategory(id: 1);
    expect(a.hashCode, b.hashCode);
  });

  test('AlbumCategory toString', () {
    final a = AlbumCategory(
      id: 3,
      name: 'Cat',
      albums: const [Album(id: 1), Album(id: 2)],
    );
    expect(a.toString(), 'AlbumCategory(id: 3, name: Cat, 2 albums)');
  });

  // ---- Hymn ----
  test('Hymn toString', () {
    const h = Hymn(id: 42, number: 10, title: 'Gracas');
    expect(h.toString(), 'Hymn(id: 42, number: 10, title: Gracas)');
  });

  test('Hymn hashCode', () {
    const a = Hymn(id: 1);
    const b = Hymn(id: 1);
    expect(a.hashCode, b.hashCode);
  });
}
