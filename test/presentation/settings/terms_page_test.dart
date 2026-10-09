import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/settings/terms_page.dart';

void main() {
  testWidgets('TermsPage isPrivacy=false renderiza Termos de Uso sem crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TermsPage(isPrivacy: false)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('TermsPage isPrivacy=true renderiza Política sem crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TermsPage(isPrivacy: true)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
