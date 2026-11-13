import 'dart:convert';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_verse_fields.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/scheduled_rotation_picker.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/scheduled/scheduled_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/scheduled/provai_panel.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/provai_catalog.dart';
import 'package:louvorja_piano_mobile/domain/repositories/provai_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_context_bar.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_session_summary.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/scheduled/scheduled_page.dart';

class _Provai implements ProvaiRepository {
  int downloads = 0;
  @override
  Future<List<ProvaiEpisode>> episodes(ProvaiSource source) async => [
    ProvaiEpisode(
      date: DateTime(2099, 11, 14),
      title: 'Gratidão',
      url: 'https://example.org/video.mp4',
    ),
  ];
  @override
  Future<String> download(ProvaiEpisode episode) async {
    downloads++;
    return '/local/video.mp4';
  }
}

void main() {
  testWidgets('Provai carrega, baixa e agenda episódio uma única vez', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScheduledRepository(await SharedPreferences.getInstance());
    final remote = _Provai();
    final bloc = ScheduledBloc(repo, provaiRepository: remote)
      ..add(const ScheduledLoadRequested());
    await bloc.stream.first;
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: BlocBuilder<ScheduledBloc, ScheduledState>(
              builder: (_, state) => ProvaiPanel(state: state),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('liturgy.parity.loadEpisodes'));
    await tester.pumpAndSettle();
    expect(find.text('Gratidão'), findsOneWidget);
    await tester.tap(find.text('liturgy.parity.downloadUpcoming'));
    await tester.pumpAndSettle();
    expect(repo.loadItems().single.content?['filePath'], '/local/video.mp4');
    expect(remote.downloads, 1);
    await tester.tap(find.text('liturgy.parity.downloadUpcoming'));
    await tester.pumpAndSettle();
    expect(remote.downloads, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('versículo usa catálogo offline e troca capítulo e seleção', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'liturgy.catalog.pt.bible_books': jsonEncode([
        const BibleBook(
          id: 1,
          name: 'Gênesis',
          abbreviation: 'Gn',
          chapters: 3,
          bookNumber: 1,
        ).toJson(),
      ]),
    });
    final book = ValueNotifier<int?>(null), chapter = ValueNotifier<int?>(null);
    final numbers = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiturgyVerseFields(
            book: book,
            chapter: chapter,
            numbers: numbers,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gênesis').last);
    await tester.pumpAndSettle();
    expect(book.value, 1);
    expect(chapter.value, 1);
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    expect(chapter.value, 3);
    await tester.enterText(find.byType(TextField), '1-3');
    expect(numbers.text, '1-3');
    await tester.pumpWidget(const SizedBox());
    book.dispose();
    chapter.dispose();
    numbers.dispose();
  });
  testWidgets('rotação seleciona entrada persistida e retorna da gestão', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScheduledRepository(await SharedPreferences.getInstance());
    final rotation = await repo.upsertCategory(name: 'Provai');
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduledRotationPicker(
            value: null,
            onChanged: (id) => selected = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liturgy-scheduled-rotation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provai').last);
    await tester.pumpAndSettle();
    expect(selected, rotation.id);
    await tester.tap(find.text('liturgy.parity.manageScheduled'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduledPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ScheduledRotationPicker), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('avulsa: cria, renomeia, clona e exclui com confirmação', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = LiturgyRepository(await SharedPreferences.getInstance());
    await repo.saveItems(LiturgyWeekday.monday, [
      const LiturgyItem(
        id: 'n',
        type: LiturgyItemType.annotation,
        name: 'Texto',
      ),
    ]);
    final bloc = LiturgyBloc(repo)
      ..add(const LiturgyLoadRequested(LiturgyWeekday.sunday));
    await bloc.stream.first;
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: BlocBuilder<LiturgyBloc, LiturgyState>(
              builder: (_, state) =>
                  LiturgyContextBar(state: state as LiturgyLoaded),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liturgy-custom-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('liturgy-custom-name')),
      'Especial',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repo.loadCustomLiturgies().single.name, 'Especial');
    await tester.tap(find.byTooltip('liturgy.parity.renameCustom'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('liturgy-custom-name')),
      'Casamento',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repo.loadCustomLiturgies().single.name, 'Casamento');
    await tester.tap(find.byKey(const Key('liturgy-clone-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('liturgy.days.monday'));
    await tester.pumpAndSettle();
    expect(repo.loadCustomLiturgies().single.items.single.name, 'Texto');
    expect(repo.loadItems(LiturgyWeekday.monday).single.id, 'n');
    await tester.tap(find.byTooltip('liturgy.parity.deleteCustom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repo.loadCustomLiturgies(), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('resumo exibe relógio, inicia e para contagem e limpa horários', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = LiturgyRepository(await SharedPreferences.getInstance());
    await repo.writeSessionTimes(
      'sunday',
      startTime: '08:00',
      endTime: '23:59',
    );
    final bloc = LiturgyBloc(repo)
      ..add(const LiturgyLoadRequested(LiturgyWeekday.sunday));
    await bloc.stream.first;
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: BlocBuilder<LiturgyBloc, LiturgyState>(
              builder: (_, state) =>
                  LiturgySessionSummary(state: state as LiturgyLoaded),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cult-current-clock')), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cult-timer-toggle')));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<Text>(find.byKey(const Key('cult-timer-display'))).data,
      isNot('—'),
    );
    await tester.tap(find.byKey(const Key('cult-timer-toggle')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('cult-timer-display'))).data,
      '—',
    );
    await tester.tap(find.byTooltip('liturgy.parity.clearTime').first);
    await tester.pumpAndSettle();
    expect(repo.readSessionTimes('sunday')['startTime'], isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('agenda cria rotação e importa trimestre pela interface', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: ScheduledPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scheduled-new-rotation')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Entrada');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    final repo = ScheduledRepository(await SharedPreferences.getInstance());
    expect(repo.loadCategories().single.name, 'Entrada');
    await tester.tap(find.text('liturgy.parity.pasteQuarter'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('scheduled-quarter-text')),
      '14/11\nEntrada: 42 - Adoração',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('liturgy.parity.applyQuarter'));
    await tester.pumpAndSettle();
    expect(repo.loadItems().single.content?['musicId'], 42);
    expect(repo.loadCategories(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
