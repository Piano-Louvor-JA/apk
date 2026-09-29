library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/error_view.dart';

void main() {
  group('ErrorView', () {
    testWidgets('exibe mensagem de erro', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(message: 'Falha ao carregar hinos')),
        ),
      );

      expect(find.text('Falha ao carregar hinos'), findsOneWidget);
    });

    testWidgets('exibe título padrão "Algo deu errado"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(message: 'Erro')),
        ),
      );

      expect(find.text('Algo deu errado'), findsOneWidget);
    });

    testWidgets('exibe botão "Tentar novamente" quando onRetry fornecido', (
      tester,
    ) async {
      var retryCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Erro de rede',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      final button = find.byType(FilledButton);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(retryCalled, isTrue);
    });

    testWidgets('NÃO exibe botão quando onRetry é null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(message: 'Erro')),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
