// SPEC 7 (apk#92) — banner "modo offline" (não bloqueia uso).
//
// Nota: easy_localization mantém singleton global — múltiplos pumpWidget
// com EasyLocalization novo no MESMO processo quebram a árvore. Por isso
// os dois estados são testados num único testWidgets (troca via setState
// equivalente: pumpWidget com outra árvore reusa o root).
library;

import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/offline_banner.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/offline_status_scope.dart';
import 'package:louvorja_piano_mobile/core/services/connectivity_service.dart';

class _Translations extends AssetLoader {
  const _Translations(this.values);
  final Map<String, dynamic> values;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}

Future<void> _pumpOffline(WidgetTester tester, bool offline) async {
  final json = await tester.runAsync(
    () => rootBundle.loadString('assets/translations/pt-BR.json'),
  );
  final translations = jsonDecode(json!) as Map<String, dynamic>;
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('pt', 'BR')],
      path: 'assets/translations',
      assetLoader: _Translations(translations),
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

class _Status extends OfflineStatusController {
  final changes = StreamController<bool>.broadcast();
  @override
  bool get isOffline => true;
  @override
  Stream<bool> get onOfflineChanged => changes.stream;
  @override
  Future<void> start() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('banner permite tocar no conteúdo sob o aviso', (tester) async {
    final status = _Status();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineStatusScope(
            controller: status,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    await tester.tapAt(const Offset(100, 10));
    expect(taps, 1);
    status.changes.add(false);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await status.changes.close();
  });

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
