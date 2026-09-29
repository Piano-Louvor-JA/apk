library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/glass_card.dart';

void main() {
  group('GlassCard', () {
    testWidgets('renderiza child corretamente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GlassCard(child: Text('Conteúdo do card'))),
        ),
      );

      expect(find.text('Conteúdo do card'), findsOneWidget);
    });

    testWidgets('usa BackdropFilter (glass morphism)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(child: SizedBox(width: 100, height: 100)),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('usa ClipRRect (clipping para bordas assimétricas)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(child: SizedBox(width: 100, height: 100)),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('aceita padding customizado', (tester) async {
      const customPadding = EdgeInsets.all(32);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(padding: customPadding, child: Text('Teste')),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final padding = container.padding as EdgeInsets?;
      // GlassCard usa Container internamente com padding
      expect(padding, isNotNull);
    });
  });
}
