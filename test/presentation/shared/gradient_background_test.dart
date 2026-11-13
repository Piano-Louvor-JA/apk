library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/app/theme/app_colors.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/gradient_background.dart';

void main() {
  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<Container>(find.byType(Container).first);
    return container.decoration as BoxDecoration;
  }

  group('GradientBackground', () {
    testWidgets('renderiza child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GradientBackground(child: Text('Dentro'))),
        ),
      );

      expect(find.text('Dentro'), findsOneWidget);
    });

    testWidgets('nao usa degrade, que gera faixas visiveis na tela', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GradientBackground(child: SizedBox.expand())),
        ),
      );

      expect(decorationOf(tester).gradient, isNull);
    });

    testWidgets('dark mode usa o fundo do tema (#131313)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: EtherealLumensColors.surface,
          ),
          home: const Scaffold(
            body: GradientBackground(child: SizedBox.expand()),
          ),
        ),
      );

      expect(decorationOf(tester).color, const Color(0xFF131313));
    });

    testWidgets('light mode usa o fundo do tema (#F8F9FF)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: LuminousClarityColors.surface,
          ),
          home: const Scaffold(
            body: GradientBackground(child: SizedBox.expand()),
          ),
        ),
      );

      expect(decorationOf(tester).color, const Color(0xFFF8F9FF));
    });
  });
}
