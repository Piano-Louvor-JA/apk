import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/playlist_storage.dart';

/// Paridade 1:1 com playlist-storage.ts do web — playlist = seleção de
/// hinos do acervo, 100% local, sem auth. Mesmas regras de comportamento.
void main() {
  late PlaylistStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = PlaylistStorage();
  });

  PlaylistItem item(int musicId, {int? albumId, String title = 'Hino'}) =>
      PlaylistItem(musicId: musicId, albumId: albumId, title: title);

  group('criar / listar / renomear / excluir', () {
    test('create: nome trimmed, items vazio, timestamps', () async {
      final p = await storage.create('  Culto sábado  ');
      expect(p.name, 'Culto sábado');
      expect(p.items, isEmpty);
      expect(p.id, isNotEmpty);
      expect(p.createdAt, p.updatedAt);
    });

    test('list: reflete o que foi criado', () async {
      await storage.create('A');
      await storage.create('B');
      final list = await storage.list();
      expect(list.map((p) => p.name), containsAll(['A', 'B']));
    });

    test('read corrompido retorna lista vazia (não explode)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('louvorja.playlists', '{não é json');
      expect(await storage.read(), isEmpty);
    });

    test('rename: atualiza nome e updatedAt, mantém id/createdAt', () async {
      final p = await storage.create('Velha');
      final updated = await storage.rename(p.id, 'Nova');
      expect(updated, isNotNull);
      expect(updated!.name, 'Nova');
      expect(updated.id, p.id);
      expect(updated.createdAt, p.createdAt);
      expect(
        updated.updatedAt.isAfter(p.updatedAt) ||
            updated.updatedAt == p.updatedAt,
        isTrue,
      );
    });

    test('rename de id inexistente → null', () async {
      expect(await storage.rename('não-existe', 'X'), isNull);
    });

    test('delete: true quando existe, false quando não', () async {
      final p = await storage.create('A');
      expect(await storage.delete(p.id), isTrue);
      expect(await storage.delete(p.id), isFalse);
      expect(await storage.list(), isEmpty);
    });
  });

  group('itens (hinos do acervo)', () {
    test('addItem: empurra no fim e retorna added=true', () async {
      final p = await storage.create('Culto');
      final result = await storage.addItem(p.id, item(12, albumId: 3));
      expect(result!.added, isTrue);
      expect(result.playlist.items.single.musicId, 12);
      expect(result.playlist.items.single.albumId, 3);
    });

    test('addItem em playlist inexistente → null', () async {
      expect(await storage.addItem('nada', item(1)), isNull);
    });

    test(
      'toque duplo: mesma faixa em sequência NÃO adiciona de novo',
      () async {
        final p = await storage.create('Culto');
        await storage.addItem(p.id, item(12, albumId: 3));
        final again = await storage.addItem(p.id, item(12, albumId: 3));
        expect(again!.added, isFalse);
        expect((await storage.list()).first.items, hasLength(1));
      },
    );

    test('mesma faixa NÃO consecutiva pode repetir (ordem importa)', () async {
      final p = await storage.create('Culto');
      await storage.addItem(p.id, item(12, albumId: 3));
      await storage.addItem(p.id, item(13, albumId: 3));
      final again = await storage.addItem(p.id, item(12, albumId: 3));
      expect(again!.added, isTrue);
      expect((await storage.list()).first.items, hasLength(3));
    });

    test('removeItem: remove por índice e mantém o resto', () async {
      final p = await storage.create('Culto');
      await storage.addItem(p.id, item(1));
      await storage.addItem(p.id, item(2));
      await storage.addItem(p.id, item(3));
      final updated = await storage.removeItem(p.id, 1);
      expect(updated!.items.map((i) => i.musicId), [1, 3]);
    });

    test('removeItem: índice inválido → null', () async {
      final p = await storage.create('Culto');
      await storage.addItem(p.id, item(1));
      expect(await storage.removeItem(p.id, 5), isNull);
      expect(await storage.removeItem(p.id, -1), isNull);
    });
  });

  group('persistência real (SharedPreferences)', () {
    test('dados sobrevivem a nova instância (reload do app)', () async {
      final p = await storage.create('Culto');
      await storage.addItem(p.id, item(340, albumId: 7, title: 'Ruma'));

      // nova instância = simula reinício do app
      final storage2 = PlaylistStorage();
      final list = await storage2.list();
      expect(list, hasLength(1));
      expect(list.first.name, 'Culto');
      expect(list.first.items.single.musicId, 340);
      expect(list.first.items.single.title, 'Ruma');
    });

    test('JSON compatível com o formato do web (camelCase)', () async {
      final prefs = await SharedPreferences.getInstance();
      // o web grava exatamente esse shape em localStorage:
      await prefs.setString(
        'louvorja.playlists',
        jsonEncode([
          {
            'id': 'abc',
            'name': 'Do Web',
            'items': [
              {'musicId': 5, 'albumId': 2, 'title': 'Hino Web'},
            ],
            'createdAt': '2026-09-11T12:00:00.000Z',
            'updatedAt': '2026-09-11T12:00:00.000Z',
          },
        ]),
      );
      final list = await storage.list();
      expect(list.single.name, 'Do Web');
      expect(list.single.items.single.musicId, 5);
      // e o Dart consegue editar o que o web criou:
      final updated = await storage.rename('abc', 'Editado no APK');
      expect(updated!.name, 'Editado no APK');
    });
  });
}
