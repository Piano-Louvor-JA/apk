import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';

/// Store local offline-first: músicas/coletâneas criadas SEM auth ficam
/// só no dispositivo (JSON local), nunca vão pra API.
void main() {
  late LocalCustomStore store;

  setUp(() {
    store = LocalCustomStore(null); // modo memória (mesma semântica web)
  });

  group('coletâneas locais (sem auth)', () {
    test('criar sem conta: id negativo, author local', () {
      final c = store.createLocalCollection('Minha Coletânea');
      expect(c['id'], lessThan(0));
      expect(c['name'], 'Minha Coletânea');
      expect(store.listLocalCollections(), hasLength(1));
    });

    test('ids negativos incrementam sem colidir com API positiva', () {
      final a = store.createLocalCollection('A');
      final b = store.createLocalCollection('B');
      expect((a['id'] as num).toInt(), lessThan(0));
      expect(b['id'], isNot(a['id']));
    });

    test('renomear e excluir', () {
      final c = store.createLocalCollection('Velha');
      final id = (c['id'] as num).toInt();
      store.renameLocalCollection(id, 'Nova');
      expect(store.listLocalCollections().first['name'], 'Nova');
      store.deleteLocalCollection(id);
      expect(store.listLocalCollections(), isEmpty);
    });
  });

  group('músicas locais (sem auth)', () {
    test('salvar música com estrofes e caminho de áudio local', () {
      final coll = store.createLocalCollection('C');
      final m = store.saveLocalMusic(
        collectionId: (coll['id'] as num).toInt(),
        name: 'Hino Local',
        lyric: 'Verso 1\n\nVerso 2',
        audioPath: '/sandbox/audio/hino.mp3',
        slides: [
          {'text': 'Verso 1', 'time': '00:00.000', 'order': 0},
          {'text': 'Verso 2', 'time': '00:05.000', 'order': 1},
        ],
      );
      expect(m['id'], lessThan(0));
      final list = store.listLocalMusics((coll['id'] as num).toInt());
      expect(list, hasLength(1));
      expect(list.first['slides'], hasLength(2));
      expect(list.first['audio_path'], '/sandbox/audio/hino.mp3');
    });

    test('listar por coletânea filtra certo', () {
      final c1 = store.createLocalCollection('C1');
      final c2 = store.createLocalCollection('C2');
      store.saveLocalMusic(collectionId: (c1['id'] as num).toInt(), name: 'M1');
      store.saveLocalMusic(collectionId: (c2['id'] as num).toInt(), name: 'M2');
      expect(
        store.listLocalMusics((c1['id'] as num).toInt()).single['name'],
        'M1',
      );
      expect(
        store.listLocalMusics((c2['id'] as num).toInt()).single['name'],
        'M2',
      );
    });

    test('excluir coletânea não apaga músicas órfãs (dados preservados)', () {
      final c = store.createLocalCollection('C');
      final cid = (c['id'] as num).toInt();
      store.saveLocalMusic(collectionId: cid, name: 'M');
      store.deleteLocalCollection(cid);
      expect(
        store.listLocalMusics(cid),
        hasLength(1),
        reason: 'música fica preservada; UI decide o que mostrar',
      );
    });
  });
}
