import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_pdf_page.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_gallery_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/rich_notes_editor_page.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_text_control_page.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_web_control_page.dart';
import '../../helpers/liturgy_webview_fake.dart';

void main() {
  late LiturgyWebViewFake platform;
  setUp(() {
    platform = LiturgyWebViewFake();
    WebViewPlatform.instance = platform;
  });
  testWidgets(
    'PDF navega pelas páginas renderizadas sem abrir navegador externo',
    (tester) async {
      const channel = MethodChannel('app.louvorja/liturgy-documents');
      final png = File(
        'test/presentation/liturgy/goldens/liturgy_timeline_light.png',
      ).readAsBytesSync();
      final pages = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'pdfInfo') return 2;
            pages.add((call.arguments as Map)['page'] as int);
            return png;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: LiturgyPdfPage(path: '/culto.pdf', title: 'Culto'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('remote.next'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('remote.previous'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(pages, [0, 1, 0]);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('galeria permite avançar e voltar com prévia offline', (
    tester,
  ) async {
    final paths = [
      'test/presentation/liturgy/goldens/liturgy_timeline_light.png',
      'test/presentation/liturgy/goldens/liturgy_timeline_dark.png',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: LiturgyGalleryPage(title: 'Imagens', paths: paths),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('remote.next'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('remote.previous'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('liturgy.parity.project'));
    await tester.pumpAndSettle();
    expect(find.text('liturgy.parity.connectScreens'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'editor mantém HTML seguro, aplica formatação e salva resultado sanitizado',
    (tester) async {
      String? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const RichNotesEditorPage(
                        html: '<p>Inicial</p><script>bad()</script>',
                      ),
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      final web = platform.controllers.single;
      expect(web.html, contains('<p>Inicial</p>'));
      expect(web.html, isNot(contains('bad()')));
      await tester.tap(find.byTooltip('liturgy.richNotes.bold'));
      await tester.pump();
      expect(web.scripts.last, contains('bold'));
      await tester.tap(find.byTooltip('liturgy.richNotes.color'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('#ffffff'));
      await tester.pumpAndSettle();
      expect(web.scripts.last, contains('#ffffff'));
      web.result = '"<p><b>Final</b><script>bad()</script></p>"';
      await tester.tap(find.byTooltip('liturgy.actions.save'));
      await tester.pumpAndSettle();
      expect(saved, '<p><b>Final</b></p>');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'controle de anotação edita e devolve o texto para persistência',
    (tester) async {
      LiturgyItem? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: LiturgyTextControlPage(
            item: const LiturgyItem(
              id: 'n',
              type: LiturgyItemType.annotation,
              name: 'Título',
              notesHtml: '<p>Antes</p>',
              titleColor: '#ff0000',
            ),
            onChanged: (item) => changed = item,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.controllers.first.html, contains('#ff0000'));
      await tester.tap(find.byTooltip('liturgy.actions.edit'));
      await tester.pumpAndSettle();
      platform.controllers.last.result = '"<p>Depois</p>"';
      await tester.tap(find.byTooltip('liturgy.actions.save'));
      await tester.pumpAndSettle();
      expect(changed!.notesHtml, '<p>Depois</p>');
      expect(changed!.subtitle, 'Depois');
      await tester.tap(find.byTooltip('liturgy.parity.project'));
      await tester.pumpAndSettle();
      expect(find.text('liturgy.parity.connectScreens'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'mídia local oferece pausa e retoma sem redefinir a variável JS',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiturgyWebControlPage(
            title: 'Vídeo',
            url: '/video.mp4',
            local: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final web = platform.controllers.single;
      expect(web.url, '/video.mp4');
      await tester.tap(find.byTooltip('remote.pause'));
      await tester.pump();
      expect(web.scripts.last, contains('v.pause()'));
      await tester.tap(find.byTooltip('remote.play'));
      await tester.pump();
      expect(web.scripts.last, contains('v.play()'));
      expect(web.scripts.last, startsWith('(()=>'));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
