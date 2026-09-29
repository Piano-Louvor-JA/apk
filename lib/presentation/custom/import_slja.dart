import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/core/services/slja.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_file_api.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_lyric_slide.dart'
    show msToDbTime;

/// Importa um .slja (LouvorJA Delphi) como música custom na coletânea.
///
/// Fluxo: escolher arquivo → parse → upload do áudio (se houver) → cria
/// música → cria estrofes com tempo_hms → snackbars de progresso.
Future<void> importSljaIntoCollection(
  BuildContext context, {
  required CustomCatalogApiImpl api,
  required CustomFileApi fileApi,
  required CustomCollection collection,
  required String bearerToken,
  required VoidCallback onDone,
}) async {
  const typeGroup = XTypeGroup(
    label: 'Apresentação LouvorJA',
    extensions: ['slja', 'zip'],
  );
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await File(file.path).readAsBytes();
    final archive = parseSlja(bytes);

    // Slides de letra (CAPA vira parte do nome, não estrofe — igual desktop).
    final lyricSlides = archive.slides.where((s) => s.type != 'CAPA').toList();

    // 1. upload do áudio
    int? idFileAudio;
    final audio = archive.audio;
    if (audio != null) {
      final tmp = File(
        '${Directory.systemTemp.path}/slja_${DateTime.now().millisecondsSinceEpoch}_${audio.name}',
      );
      await tmp.writeAsBytes(audio.bytes);
      final upload = await fileApi.upload(
        tmp,
        kind: 'audio',
        bearerToken: bearerToken,
      );
      idFileAudio = upload.idFile;
      tmp.deleteSync();
    }

    // 2. cria a música (letra completa no campo lyric pra compat, como o
    // desktop faz; estrofes são a fonte real dos slides)
    final musicId = await api.createMusic(
      collectionId: collection.id,
      name: archive.title,
      idFileAudio: idFileAudio,
      bearerToken: bearerToken,
    );

    // 3. estrofes com tempo_hms (tempo do .slja)
    for (var i = 0; i < lyricSlides.length; i++) {
      final s = lyricSlides[i];
      await api.addLyric(
        musicId: musicId,
        lyric: s.lyric,
        auxLyric: s.auxiliaryLyric,
        time: s.timeMs > 0 ? msToDbTime(s.timeMs) : '00:00.000',
        order: i,
        bearerToken: bearerToken,
      );
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '"${archive.title}" importada: ${lyricSlides.length} estrofes'
          '${audio != null ? ' + áudio' : ''}!',
        ),
      ),
    );
    onDone();
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Falha ao importar .slja: $e')),
    );
  }
}

/// ms → formato do DB custom: MM:SS.mmm

