import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/entities/lyric_slides.dart';

const _enabled = String.fromEnvironment('LOUVORJA_E2E') == '1';
const _token = String.fromEnvironment('API_TOKEN');
const _base = 'https://api.pianolouvorja.com.br/json_db';

void main() {
  test('E2E: busca hino, abre detalhe e gera slides de lyricRaw', () async {
    final dio = Dio(
      BaseOptions(
        headers: {'Api-Token': _token, 'User-Agent': 'LouvorJA/1.0'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final index = (await dio.get<dynamic>('$_base/pt_musics')).data as List;
    final results = index
        .map((row) => Hymn.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((hymn) => hymn.id > 0 && (hymn.title ?? '').isNotEmpty)
        .take(25);
    Hymn? detail;
    for (final result in results) {
      final response = await dio.get<dynamic>('$_base/music_${result.id}');
      final candidate = Hymn.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (candidate.lyricRaw?.isNotEmpty ?? false) {
        detail = candidate;
        break;
      }
    }
    expect(
      detail,
      isNotNull,
      reason: 'catálogo precisa conter hino com lyricRaw',
    );
    final slides = LyricSlides.fromApi(
      musicName: detail!.title ?? '',
      coverUrl: detail.imageUrl,
      raw: detail.lyricRaw!,
    );

    expect(slides.slides.first.text, detail.title);
    expect(slides.slides.length, greaterThan(1));
  }, skip: !_enabled ? 'Defina LOUVORJA_E2E=1 para rede de produção.' : false);
}
