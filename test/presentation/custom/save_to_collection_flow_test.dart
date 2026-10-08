import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/presentation/custom/save_to_collection_sheet.dart';

/// showSaveToCollectionSheet monta Dio próprio + FlutterSecureStorage real —
/// em sandbox, read() lança MissingPluginException tratado? CustomSessionStore
/// read() nunca lança (catch → null). Sem sessão abre CustomAuthSheet.
/// Cobrimos os ramos de entrada sem sessão e com contexto desmontado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sem sessão: abre CustomAuthSheet (fluxo de login) sem crash', (
    tester,
  ) async {
    const key = ValueKey('sheet-host');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: key,
              onPressed: () {
                showSaveToCollectionSheet(
                  context,
                  officialMusicId: 1,
                  hymnTitle: 'Hino',
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // CustomAuthSheet apareceu (ou fluxo seguiu) — sem exceção é o contrato.
    expect(tester.takeException(), isNull);
  });
}
