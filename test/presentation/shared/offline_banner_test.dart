// SPEC 7 (apk#92) — banner "modo offline" (não bloqueia uso).
//
// Nota: easy_localization mantém singleton global — múltiplos pumpWidget
// com EasyLocalization novo no MESMO processo quebram a árvore. Por isso
// os dois estados são testados num único testWidgets (troca via setState
// equivalente: pumpWidget com outra árvore reusa o root).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/offline_banner.dart';

Future<void> _pumpOffline(WidgetTester tester, bool offline) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('pt', 'BR')],
      path: 'assets/translations',
      startLocale: const Locale('pt', 'BR'),
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: _Harness(offline: offline),
        ),
      ),
    ),
  );
  // EasyLocalization precisa de varios frames pra carregar o asset.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

class _Harness extends StatefulWidget {
  const _Harness({required this.offline});

  final bool offline;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: OfflineBanner(isOffline: widget.offline));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('banner offline: mostra aviso sem rede, some quando online', (
    tester,
  ) async {
    await _pumpOffline(tester, true);
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.text('Modo offline — usando conteúdo baixado'), findsOneWidget);

    // rede volta → banner sai (não bloqueia nada)
    await _pumpOffline(tester, false);
    await tester.pump();
    expect(find.byKey(const Key('offline-banner')), findsNothing);
  });
}
