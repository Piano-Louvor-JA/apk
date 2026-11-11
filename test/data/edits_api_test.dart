import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/edits_api_impl.dart';
import 'package:louvorja_piano_mobile/data/models/applied_edit_model.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late EditsApiImpl api;

  setUp(() {
    dio = _MockDio();
    api = EditsApiImpl(
      dio: dio,
      apiBaseUrl: 'https://api.test',
      bearerToken: () async => 'tok',
    );
  });

  group('EditsApiImpl.fetchApplied (RF-08)', () {
    test('retorna o edit applied da música (contrato camelCase da API)', () async {
      when(() => dio.request<dynamic>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        data: {
          'applied': [
            {'musicId': 42, 'lyrics': '[{"text":"aprovado"}]', 'timing': null},
          ],
        },
      ));

      final applied = await api.fetchApplied(42);

      expect(applied, isNotNull);
      expect(applied!.lyrics, '[{"text":"aprovado"}]');
      expect(applied.timing, isNull);
      final opts = verify(() => dio.request<dynamic>(captureAny(),
              data: any(named: 'data'),
              options: any(named: 'options')))
          .captured
          .first as String;
      expect(opts, contains('/v1/custom/edits/applied'));
      expect(opts, contains('musicIds=42'));
    });

    test('erro de rede → null (oficial intacta)', () async {
      when(() => dio.request<dynamic>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        error: 'down',
      ));

      expect(await api.fetchApplied(42), isNull);
    });

    test('sem hit para a música → null', () async {
      when(() => dio.request<dynamic>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        data: {'edits': <dynamic>[]},
      ));

      expect(await api.fetchApplied(42), isNull);
    });
  });

  group('EditsApiImpl.fetchMine (RF-05)', () {
    test('lista edits do autor com status e motivo', () async {
      when(() => dio.request<dynamic>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenAnswer((_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: ''),
        data: [
          {
            'id': 1,
            'music_id': 42,
            'status': 'approved',
            'reason': null,
          },
          {
            'id': 2,
            'music_id': 77,
            'status': 'rejected',
            'reason': 'letra diverge da fonte oficial',
          },
        ],
      ));

      final mine = await api.fetchMine();

      expect(mine, hasLength(2));
      expect(mine[0].status, 'approved');
      expect(mine[1].reason, contains('diverge'));
    });

    test('erro → lista vazia (não quebra a tela)', () async {
      when(() => dio.request<dynamic>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
      ));

      expect(await api.fetchMine(), isEmpty);
    });
  });

  group('AppliedEditModel (RF-08 paridade desktop)', () {
    test('aplicar por cima do hino oficial PRESERVA metadados', () {
      final hymnJson = {
        'id': 42,
        'title': 'Hino Oficial 42',
        'lyric': jsonEncode([
          {'text': 'verso oficial', 'time': '00:00:01'},
        ]),
      };

      final applied = AppliedEditModel(
        musicId: 42,
        lyrics: jsonEncode([
          {'text': 'verso corrigido', 'time': '00:00:02'},
        ]),
        timing: null,
      );

      final result = applied.applyToHymnJson(hymnJson);

      expect(result['title'], 'Hino Oficial 42'); // metadado intacto
      final lyric = jsonDecode(result['lyric'] as String) as List;
      expect((lyric.first as Map)['text'], 'verso corrigido');
    });

    test('edit parcial (lyrics null) NÃO apaga letra oficial', () {
      final hymnJson = {
        'id': 42,
        'title': 'Hino',
        'lyric': jsonEncode([
          {'text': 'oficial'},
        ]),
      };

      final applied = AppliedEditModel(musicId: 42, lyrics: null, timing: 'T');
      final result = applied.applyToHymnJson(hymnJson);

      final lyric = jsonDecode(result['lyric'] as String) as List;
      expect((lyric.first as Map)['text'], 'oficial');
    });

    test('lyrics JSON inválido → oficial intacta', () {
      final hymnJson = {'id': 42, 'lyric': jsonEncode([{'text': 'oficial'}])};
      final applied = AppliedEditModel(musicId: 42, lyrics: 'não-json', timing: null);
      final result = applied.applyToHymnJson(hymnJson);
      final lyric = jsonDecode(result['lyric'] as String) as List;
      expect((lyric.first as Map)['text'], 'oficial');
    });
  });
}
