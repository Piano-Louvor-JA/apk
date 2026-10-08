
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';
import 'package:louvorja_piano_mobile/presentation/custom/save_to_collection_sheet.dart';

/// Storage falso em memória (sem plugin nativo).
class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> backing = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final named = invocation.namedArguments;
    if (invocation.memberName == #write) {
      final key = named[#key] as String;
      final value = named[#value] as String?;
      if (value == null) {
        backing.remove(key);
      } else {
        backing[key] = value;
      }
      return Future<void>.value();
    }
    if (invocation.memberName == #read) {
      return Future<String?>.value(backing[named[#key] as String]);
    }
    if (invocation.memberName == #delete) {
      backing.remove(named[#key] as String);
      return Future<void>.value();
    }
    return null;
  }
}

CustomSession _session(String token) => CustomSession(
  token: token,
  user: const CustomUser(
    idUser: 7,
    email: 'r@test',
    displayName: 'Rafael',
  ),
);

/// O sheet interno usa Dio da showSaveToCollectionSheet contra a URL de
/// produção; aqui só interessa o contrato de sessão → sem rede acessível o
/// _load falha e cai no ramo de erro, cobrindo o estado do sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('com sessão salva: abre picker e mostra erro de carregamento',
      (tester) async {
    final storage = _FakeStorage();
    final store = CustomSessionStore(storage: storage);
    await store.save(_session('tok-1'));

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: key,
              onPressed: () => showSaveToCollectionSheet(
                context,
                officialMusicId: 1,
                hymnTitle: 'Hino 1',
                sessionStore: store,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(key));
    await tester.pump();
    // Dio com timeout curto contra host inalcançável em sandbox.
    await tester.pumpAndSettle(const Duration(seconds: 20));

    expect(
      find.text('Não foi possível carregar as coletâneas.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
