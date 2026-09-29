library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/section_header.dart';

void main() {
  group('SectionHeader', () {
    testWidgets('exibe título', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionHeader(title: 'Coletâneas')),
        ),
      );

      expect(find.text('Coletâneas'), findsOneWidget);
    });

    testWidgets('exibe subtítulo quando fornecido', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Hinos',
              subtitle: '12 coletâneas disponíveis',
            ),
          ),
        ),
      );

      expect(find.text('Hinos'), findsOneWidget);
      expect(find.text('12 coletâneas disponíveis'), findsOneWidget);
    });

    testWidgets('exibe ícone quando fornecido', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Busca', icon: Icons.search),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets(
      'exibe botão de ação quando actionLabel + onActionTap fornecidos',
      (tester) async {
        var actionCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SectionHeader(
                title: 'Favoritos',
                actionLabel: 'Ver todos',
                onActionTap: () => actionCalled = true,
              ),
            ),
          ),
        );

        final button = find.text('Ver todos');
        expect(button, findsOneWidget);

        await tester.tap(button);
        await tester.pump();

        expect(actionCalled, isTrue);
      },
    );

    testWidgets('NÃO exibe TextButton quando actionLabel é null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionHeader(title: 'Título')),
        ),
      );

      expect(find.byType(TextButton), findsNothing);
    });
  });
}
