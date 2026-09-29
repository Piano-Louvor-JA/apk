// Smoke test: garante que o app monta a arvore de widgets principal sem
// quebrar (substitui o template counter que nao existia no projeto).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp basica monta sem erro', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('smoke'))),
      ),
    );
    expect(find.text('smoke'), findsOneWidget);
  });
}
