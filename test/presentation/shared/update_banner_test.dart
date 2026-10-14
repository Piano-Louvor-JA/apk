library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/update_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UpdateBanner renderiza versao e botao atualizar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateBanner(
            version: '0.2.0',
            apkSizeBytes: 62914560,
            onUpdate: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('0.2.0'), findsOneWidget);
    expect(find.textContaining('60.0 MB'), findsOneWidget);
    expect(find.text('Atualizar'), findsOneWidget);
  });

  testWidgets('UpdateBanner botao atualizar chama callback', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateBanner(
            version: '0.3.0',
            onUpdate: () => pressed = true,
            onDismiss: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Atualizar'));
    expect(pressed, isTrue);
  });

  testWidgets('UpdateBanner botao X chama dismiss', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateBanner(
            version: '0.4.0',
            onUpdate: () {},
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    expect(dismissed, isTrue);
  });

  testWidgets('UpdateBanner sem tamanho mostra apenas versao', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateBanner(
            version: '1.0.0',
            apkSizeBytes: null,
            onUpdate: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('1.0.0'), findsOneWidget);
    expect(find.textContaining('MB'), findsNothing);
  });

  testWidgets('UpdateBanner tamanho em KB', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateBanner(
            version: '0.5.0',
            apkSizeBytes: 512000,
            onUpdate: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('500 KB'), findsOneWidget);
  });

  testWidgets('UpdateBanner expande e recolhe notas da versão', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateBanner(
            version: '0.6.0',
            releaseNotes: 'Correção offline-first',
            onUpdate: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.text('Correção offline-first'), findsNothing);
    await tester.tap(find.textContaining('0.6.0'));
    await tester.pump();
    expect(find.text('Correção offline-first'), findsOneWidget);
    await tester.tap(find.textContaining('0.6.0'));
    await tester.pump();
    expect(find.text('Correção offline-first'), findsNothing);
  });
}
