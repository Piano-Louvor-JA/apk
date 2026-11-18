import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/scheduled_resolver.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

void main() {
  final date = DateTime(2026, 11, 14);
  const categories = [ScheduledCategory(id: 'r', name: 'Hino inicial')];
  const placeholder = LiturgyItem(
    id: 'p',
    type: LiturgyItemType.scheduled,
    name: 'Placeholder',
    categoryId: 'culto',
    scheduledRotationId: 'r',
  );
  ScheduledItem entry(Map<String, dynamic>? content, {String filePath = ''}) =>
      ScheduledItem(
        id: 'e',
        categoryId: 'r',
        date: date,
        name: 'Entrada',
        content: content,
        filePath: filePath,
      );
  test('resolve música e modo da rotação na data correta', () {
    final item = ScheduledResolver.resolve(placeholder, date, categories, [
      entry({'kind': 'music', 'musicId': 42, 'musicMode': 'instrumental'}),
    ]);
    expect(item?.type, LiturgyItemType.music);
    expect(item?.musicId, 42);
    expect(item?.musicMode, 'instrumental');
    expect(item?.categoryId, 'culto');
    expect(
      ScheduledResolver.resolve(
        placeholder,
        DateTime(2026, 11, 15),
        categories,
        [
          entry({'kind': 'music', 'musicId': 42}),
        ],
      ),
      isNull,
    );
  });
  test(
    'arquivo legado é identificado por extensão e não muda a categoria litúrgica',
    () {
      expect(
        ScheduledResolver.resolve(placeholder, date, categories, [
          entry(null, filePath: 'slides.PPTX'),
        ])?.type,
        LiturgyItemType.presentation,
      );
      expect(
        ScheduledResolver.resolve(placeholder, date, categories, [
          entry(null, filePath: 'audio.mp3'),
        ])?.type,
        LiturgyItemType.audio,
      );
    },
  );
  test('rotação legada só é associada por nome único sem acentos', () {
    const old = LiturgyItem(
      id: 'old',
      type: LiturgyItemType.scheduled,
      name: 'HÍNO INICIAL',
    );
    expect(
      ScheduledResolver.resolve(old, date, categories, [
        entry({'kind': 'annotation', 'text': 'Aviso'}),
      ])?.subtitle,
      'Aviso',
    );
    expect(
      ScheduledResolver.resolve(
        old,
        date,
        [
          ...categories,
          const ScheduledCategory(id: 'r2', name: 'Hino Inicial'),
        ],
        [
          entry({'kind': 'annotation', 'text': 'Aviso'}),
        ],
      ),
      isNull,
    );
  });
  test('resolve vídeo, versículo e anotação e rejeita conteúdo vazio', () {
    expect(
      ScheduledResolver.resolve(placeholder, date, categories, [
        entry({'kind': 'online_video', 'url': 'https://example.org/video'}),
      ])?.url,
      'https://example.org/video',
    );
    expect(
      ScheduledResolver.resolve(placeholder, date, categories, [
        entry({
          'kind': 'verse',
          'verseBookId': 1,
          'verseChapter': 2,
          'verseNumbers': '3-5',
        }),
      ])?.verseNumbers,
      '3-5',
    );
    expect(
      ScheduledResolver.resolve(placeholder, date, categories, [
        entry({'kind': 'file', 'filePath': ''}),
      ]),
      isNull,
    );
  });
}
