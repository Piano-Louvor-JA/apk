import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/rich_notes_editor_page.dart';
import '../../helpers/liturgy_webview_fake.dart';

void main() {
  testWidgets('salvar com título devolve título e texto sem quebrar a saída', (
    tester,
  ) async {
    final platform = LiturgyWebViewFake();
    WebViewPlatform.instance = platform;
    String? html;
    String? title;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              html = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => RichNotesEditorPage(
                    html: '<p>lembrete</p>',
                    title: 'Anotacao',
                    onTitleSaved: (value) => title = value,
                  ),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Anotacao'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('rich-notes-title')),
      'Avisos da semana',
    );
    platform.controllers.single.result = '"<p>Texto novo</p>"';
    await tester.tap(find.byTooltip('liturgy.actions.save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(title, 'Avisos da semana');
    expect(html, '<p>Texto novo</p>');
  });
}
