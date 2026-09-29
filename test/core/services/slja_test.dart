import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/slja.dart';

/// Constrói um .slja "estilo Delphi": INI Latin-1, backslash nos paths,
/// letra com pipes, tempo_hms.
List<int> buildDelphiFixture() {
  const ini = '''
[Geral]
slides=3
versao=2.0
titulo=Missão Para Todos
audio=1
url_musica=audio\\missao.mp3

[Slide:1]
tipo=CAPA
letra=MISSÃO PARA TODOS

[Slide:2]
tipo=LETRA
letra=Cristo nos convida|A levar o amor|A todos os povos
letra_aux=Christ sends us|To all the nations
tempo_hms=00:00:12
cor_letra=#FFFFFF
fundo_letra=0
cor_fundo=#0A0E1A

[Slide:3]
tipo=LETRA
letra=Vai, testemunha|Do meu amor
tempo_hms=00:00:30
imagem=imagens\\fundo1.png
imagem_posicao=5
''';
  final zip = ZipEncoder().encode(
    Archive()
      ..addFile(ArchiveFile.bytes('slides.lja', latin1.encode(ini)))
      ..addFile(ArchiveFile.bytes('audio/missao.mp3', List.filled(32, 1)))
      ..addFile(ArchiveFile.bytes('imagens/fundo1.png', List.filled(16, 2))),
  );
  return zip;
}

void main() {
  group('.slja.zip (recebido via WhatsApp — zip contendo o .slja)', () {
    test('aceita .slja.zip: zip externo contendo o .slja interno', () {
      final innerSlja = ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile.bytes('musica.slja', buildDelphiFixture())),
      );
      final archive = parseSlja(innerSlja);
      expect(archive.title, 'Missão Para Todos');
      expect(archive.slides, hasLength(3));
      expect(archive.audio, isNotNull);
    });

    test('aceita .slja direto (sem wrapper zip) — compatibilidade', () {
      final archive = parseSlja(buildDelphiFixture());
      expect(archive.title, 'Missão Para Todos');
      expect(archive.slides, hasLength(3));
    });

    test('.slja.zip com múltiplos arquivos: pega o primeiro .slja', () {
      final innerSlja = ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile.bytes('leia-me.txt', utf8.encode('via zap')))
          ..addFile(ArchiveFile.bytes('missao.slja', buildDelphiFixture())),
      );
      final archive = parseSlja(innerSlja);
      expect(archive.title, 'Missão Para Todos');
    });

    test('arquivo corrupto nem zip nem slja → FormatException clara', () {
      expect(
        () => parseSlja(List<int>.filled(64, 0)),
        throwsA(isA<FormatException>()),
      );
    });
  });
  test('parse .slja estilo Delphi: título, áudio, assets, slides', () {
    final archive = parseSlja(buildDelphiFixture());

    expect(archive.title, 'Missão Para Todos');
    expect(archive.audio?.name, 'missao.mp3');
    expect(archive.audio?.bytes, hasLength(32));
    expect(archive.assets, hasLength(1));
    expect(archive.assets.first.path, 'fundo1.png');

    expect(archive.slides, hasLength(3));

    // CAPA (slide 1)
    expect(archive.slides[0].type, 'CAPA');
    expect(archive.slides[0].lyric, 'MISSÃO PARA TODOS');
    expect(archive.slides[0].timeMs, 0);

    // LETRA com pipes → quebras reais + tradução + timing
    final s2 = archive.slides[1];
    expect(s2.lyric, 'Cristo nos convida\nA levar o amor\nA todos os povos');
    expect(s2.auxiliaryLyric, 'Christ sends us\nTo all the nations');
    expect(s2.timeMs, 12000);
    expect(s2.textColor, '#FFFFFF');
    expect(s2.backgroundColor, '#0A0E1A');
    expect(s2.boxColor, isNull);

    // imagem com backslash normalizada
    final s3 = archive.slides[2];
    expect(s3.imageName, 'fundo1.png');
    expect(s3.imagePosition, 5);
    expect(s3.timeMs, 30000);
  });

  test('build → parse roundtrip preserva conteúdo', () {
    final original = SljaArchive(
      title: 'Teste Roundtrip',
      audio: const SljaAudio(name: 'a.mp3', bytes: [1, 2, 3]),
      slides: const [
        SljaSlide(type: 'CAPA', lyric: 'Capa', timeMs: 0),
        SljaSlide(
          type: 'LETRA',
          lyric: 'Linha 1\nLinha 2',
          auxiliaryLyric: 'Line 1\nLine 2',
          timeMs: 4500,
          textColor: '#FFFFFF',
          fontSize: 40,
        ),
      ],
    );

    final bytes = buildSlja(original);
    final parsed = parseSlja(bytes);

    expect(parsed.title, 'Teste Roundtrip');
    expect(parsed.audio?.name, 'a.mp3');
    expect(parsed.slides, hasLength(2));
    expect(parsed.slides[1].lyric, 'Linha 1\nLinha 2');
    expect(parsed.slides[1].auxiliaryLyric, 'Line 1\nLine 2');
    // tempo_hms tem precisão de SEGUNDOS (limitação do formato Delphi —
    // ms finos ficam no campo 'tempo' bytes-BASS, só compat).
    expect(parsed.slides[1].timeMs, 4000);
    expect(parsed.slides[1].textColor, '#FFFFFF');
    expect(parsed.slides[1].fontSize, 40);
  });

  test('tempo em bytes BASS (fallback quando não tem tempo_hms)', () {
    const ini = '''
[Geral]
slides=1
titulo=x
audio=0

[Slide:1]
tipo=LETRA
letra=a|b
tempo=176400
''';
    final zip = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile.bytes('slides.lja', latin1.encode(ini))),
    );
    final archive = parseSlja(zip);
    expect(archive.slides.single.timeMs, 1000);
  });

  test('ZIP sem slides.lja → FormatException clara', () {
    final zip = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile.bytes('outro.txt', utf8.encode('x'))),
    );
    expect(() => parseSlja(zip), throwsFormatException);
  });
}
