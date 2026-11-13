import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_site_mini_panel.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_site_session.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_web_control_page.dart';
import '../../helpers/liturgy_webview_fake.dart';

void main() {
  late LiturgyWebViewFake platform;
  setUp(() {
    platform = LiturgyWebViewFake();
    WebViewPlatform.instance = platform;
    LiturgySiteSession.current.value?.close();
  });

  testWidgets(
    'minimizar volta à lista com o site vivo; expandir reabre o mesmo site',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => _layer(child!, navigator),
          home: const Scaffold(body: Text('lista da liturgia')),
        ),
      );
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const LiturgyWebControlPage(
            title: 'Veja Imobiliária',
            url: 'https://example.test/site',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final session = LiturgySiteSession.current.value!;
      expect(platform.controllers, hasLength(1));

      await tester.tap(find.byKey(const Key('liturgy-site-minimize')));
      await tester.pumpAndSettle();
      expect(find.text('lista da liturgia'), findsOneWidget);
      expect(session.closed, isFalse);
      expect(session.minimized, isTrue);
      expect(find.byKey(const Key('liturgy-site-floating')), findsOneWidget);

      await tester.tap(find.byKey(const Key('liturgy-site-expand')));
      await tester.pumpAndSettle();
      expect(find.byType(LiturgyWebControlPage), findsOneWidget);
      expect(LiturgySiteSession.current.value, same(session));
      expect(session.minimized, isFalse);
      // Mesma página web: nada foi recarregado.
      expect(platform.controllers, hasLength(1));

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(session.closed, isTrue);
      expect(LiturgySiteSession.current.value, isNull);
      expect(find.byKey(const Key('liturgy-site-floating')), findsNothing);
    },
  );

  testWidgets('fechar pelo painel pede confirmação e encerra o site', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => _layer(child!, navigator),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final session = LiturgySiteSession.open(
      title: 'Site',
      url: 'https://example.test/a',
    )..minimize();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liturgy-site-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('liturgy-site-close-confirm')), findsOneWidget);
    await tester.tap(find.text('remote.video.closeConfirmOk'));
    await tester.pumpAndSettle();
    expect(session.closed, isTrue);
    expect(LiturgySiteSession.current.value, isNull);
  });
}

/// Como no app: o painel vive no Overlay do LocalLiturgyOverlay.
Widget _layer(Widget child, GlobalKey<NavigatorState> navigator) => Overlay(
  initialEntries: [
    OverlayEntry(
      builder: (_) => Stack(
        fit: StackFit.expand,
        children: [
          child,
          LiturgySiteMiniPanel(navigatorKey: navigator),
        ],
      ),
    ),
  ],
);
