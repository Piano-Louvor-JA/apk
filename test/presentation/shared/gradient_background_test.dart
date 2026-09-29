library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/gradient_background.dart';

void main() {
  group('GradientBackground', () {
    testWidgets('renderiza child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GradientBackground(child: Text('Dentro do gradient')),
          ),
        ),
      );

      expect(find.text('Dentro do gradient'), findsOneWidget);
    });

    testWidgets('usa Container com LinearGradient', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GradientBackground(child: SizedBox.expand())),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('dark mode usa cores escuras (#131313)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(
            body: GradientBackground(child: SizedBox.expand()),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors.first, const Color(0xFF131313));
    });

    testWidgets('light mode usa cores claras (#F8F9FF)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const Scaffold(
            body: GradientBackground(child: SizedBox.expand()),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors.first, const Color(0xFFF8F9FF));
    });
  });
}
