import 'dart:io';

// file_selector expõe esta interface transitiva no lock do app; fake do picker.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_file_api.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_music_editor_page.dart';

/// Fake do file_selector: devolve o áudio fixo na 1ª chamada, uma imagem
/// na 2ª (se configurado), depois null (cancelamento).
class _FakeFileSelector extends FileSelectorPlatform {
  final List<XFile> queue;
  int _i = 0;
  _FakeFileSelector(this.queue);

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    if (_i >= queue.length) return null;
    return queue[_i++];
  }
}

const _collection = CustomCollection(
  id: 3,
  name: 'Minha Coletânea',
  musicsCount: 0,
  isOwner: true,
);

Widget _editorLocal(LocalCustomStore store) {
  return MaterialApp(
    home: CustomMusicEditorPage(
      api: CustomCatalogApiImpl(
        fetch: (m, u, {body, bearerToken}) async => {},
        apiBaseUrl: 'https://api.test',
        filesBaseUrl: 'https://api.test/file',
      ),
      fileApi: CustomFileApi(apiBaseUrl: 'https://api.test'),
      collection: _collection,
      localStore: store,
    ),
  );
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
  await tester.pump();
}

void main() {
  late Directory tmp;
  late File audio;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('music_editor_test');
    audio = File('${tmp.path}/audio.mp3')..writeAsStringSync('audio-data');
    FileSelectorPlatform.instance = _FakeFileSelector([XFile(audio.path)]);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('CustomMusicEditorPage — validações de salvar (modo local)', () {
    testWidgets('sem nome bloqueia salvar com snackbar', (tester) async {
      await tester.pumpWidget(_editorLocal(LocalCustomStore(tmp)));
      await tester.pump();

      await _tapSave(tester);

      expect(
        find.text('Dá um nome pra música antes de salvar.'),
        findsOneWidget,
      );
    });

    testWidgets('com nome mas sem letra bloqueia salvar', (tester) async {
      await tester.pumpWidget(_editorLocal(LocalCustomStore(tmp)));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Hino Teste');
      await _tapSave(tester);

      expect(
        find.text('Escreve a letra — pelo menos uma estrofe.'),
        findsOneWidget,
      );
    });

    testWidgets('com nome e letra mas sem áudio bloqueia salvar', (
      tester,
    ) async {
      await tester.pumpWidget(_editorLocal(LocalCustomStore(tmp)));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Hino Teste');
      await tester.enterText(find.byType(TextField).at(1), 'Primeira estrofe\n\nSegunda estrofe');
      await _tapSave(tester);

      expect(
        find.text('Escolhe o áudio da música — é obrigatório pra tocar.'),
        findsOneWidget,
      );
    });
  });

  group('CustomMusicEditorPage — salvar modo local', () {
    testWidgets('salva no store com estrofes e navega pro recorder', (
      tester,
    ) async {
      final audio = File('${tmp.path}/audio.mp3')
        ..writeAsStringSync('audio-data');

      await tester.pumpWidget(_editorLocal(LocalCustomStore(tmp)));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Hino Local');
      await tester.enterText(find.byType(TextField).at(1), 'Estrofe um\n\nEstrofe dois');

      // escolhe o áudio pelo fluxo real (fake do file_selector)
      await tester.tap(find.text('Escolher áudio (obrigatório) *'));
      await tester.pump();

      await _tapSave(tester);
      await tester.pumpAndSettle();

      // Snack de sucesso + navegação pro recorder
      expect(
        find.textContaining('"Hino Local" salva neste dispositivo'),
        findsOneWidget,
      );

      // persistiu no store (disco real)
      final musics = LocalCustomStore(tmp).listLocalMusics(3);
      expect(musics, isNotEmpty);
      expect(musics.first['name'], 'Hino Local');
      expect(musics.first['audio_path'], audio.path);
      final slides = musics.first['slides'] as List<dynamic>;
      expect(slides.length, 2);
      expect(slides[0]['text'], 'Estrofe um');
      expect(slides[1]['order'], 1);
    });

    testWidgets('salvar duas vezes não duplica música (id novo por save)', (
      tester,
    ) async {
      await tester.pumpWidget(_editorLocal(LocalCustomStore(tmp)));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Hino Duplo');
      await tester.enterText(find.byType(TextField).at(1), 'Estrofe');
      await tester.tap(find.text('Escolher áudio (obrigatório) *'));
      await tester.pump();

      await _tapSave(tester);
      await tester.pumpAndSettle();

      // store persistiu exatamente 1 música
      expect(LocalCustomStore(tmp).listLocalMusics(3).length, 1);
    });
});
}
