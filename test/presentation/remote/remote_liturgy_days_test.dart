import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_liturgy_days.dart';

const _days = [
  RemoteLiturgyDay(key: 'sunday', count: 0, selected: false),
  RemoteLiturgyDay(key: 'monday', count: 0, selected: false),
  RemoteLiturgyDay(key: 'tuesday', count: 0, selected: false),
  RemoteLiturgyDay(key: 'wednesday', count: 0, selected: false),
  RemoteLiturgyDay(key: 'thursday', count: 0, selected: false),
  RemoteLiturgyDay(key: 'friday', count: 0, selected: false),
  RemoteLiturgyDay(key: 'saturday', count: 11, selected: true),
  RemoteLiturgyDay(key: 'custom', count: 2, selected: false),
];

const _customs = [
  RemoteLiturgyCustom(index: 0, name: 'teste', count: 0, selected: false),
  RemoteLiturgyCustom(index: 1, name: 'teste2', count: 18, selected: true),
];

void main() {
  late List<RemoteLiturgyDay> tapped;
  late List<RemoteLiturgyCustom> tappedCustom;

  setUp(() {
    tapped = [];
    tappedCustom = [];
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RemoteLiturgyDays(
          days: _days,
          customs: _customs,
          onSelect: tapped.add,
          onSelectCustom: tappedCustom.add,
        ),
      ),
    ),
  );

  testWidgets('lista cada liturgia avulsa pelo nome', (tester) async {
    await pump(tester);

    expect(find.text('teste'), findsOneWidget);
    expect(find.text('teste2'), findsOneWidget);
    expect(
      find.byKey(const Key('remote-liturgy-custom-filled-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('remote-liturgy-custom-filled-0')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('remote-liturgy-custom-open-1')),
      findsOneWidget,
    );
  });

  testWidgets('tocar na avulsa avisa qual foi escolhida', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('remote-liturgy-custom-1')));
    await tester.pump();

    expect(tappedCustom.single.index, 1);
  });

  testWidgets('bloco Avulsa com a lista abaixo nao faz nada ao tocar', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('remote-liturgy-day-custom')));
    await tester.pump();

    expect(tapped, isEmpty);
  });

  testWidgets('avulsa sem itens nao faz nada ao tocar', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('remote-liturgy-custom-0')));
    await tester.pump();

    expect(tappedCustom, isEmpty);
  });

  testWidgets('mostra todos os dias da semana e a avulsa', (tester) async {
    await pump(tester);

    for (final day in _days) {
      expect(find.byKey(Key('remote-liturgy-day-${day.key}')), findsOneWidget);
    }
  });

  testWidgets('dia com liturgia fica em destaque', (tester) async {
    await pump(tester);

    expect(
      find.byKey(const Key('remote-liturgy-day-filled-saturday')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('remote-liturgy-day-filled-custom')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('remote-liturgy-day-filled-monday')),
      findsNothing,
    );
  });

  testWidgets('nenhum dia mostra icone de check', (tester) async {
    await pump(tester);

    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('dia aberto no desktop fica marcado', (tester) async {
    await pump(tester);

    expect(
      find.byKey(const Key('remote-liturgy-day-open-saturday')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('remote-liturgy-day-open-custom')),
      findsNothing,
    );
  });

  testWidgets('tocar no dia avisa qual foi escolhido', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('remote-liturgy-day-saturday')));
    await tester.pump();

    expect(tapped.single.key, 'saturday');
  });

  testWidgets('dia sem liturgia nao faz nada ao tocar', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('remote-liturgy-day-monday')));
    await tester.pump();

    expect(tapped, isEmpty);
  });
}
