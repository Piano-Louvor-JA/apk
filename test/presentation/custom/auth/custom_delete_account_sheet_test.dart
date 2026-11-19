import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_delete_account_sheet.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements CustomAuthApiImpl {}

/// Exclusão de conta (App Store 5.1.1(v)): aviso + senha + botão de excluir.
void main() {
  late _MockApi api;
  late CustomAuthController controller;

  setUp(() {
    api = _MockApi();
    controller = CustomAuthController(api)
      ..status = CustomAuthStatus.authenticated
      ..session = const CustomSession(
        token: 't',
        user: CustomUser(idUser: 1, email: 'a@b.c', displayName: 'Ana'),
      );
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    CustomDeleteAccountSheet.show(context, controller),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Finder deleteButton() =>
      find.widgetWithText(FilledButton, 'Excluir definitivamente');

  testWidgets('mostra o aviso e o campo de senha', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Excluir sua conta'), findsOneWidget);
    expect(find.textContaining('Não dá para desfazer'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
  });

  testWidgets('sem senha não chama a API', (tester) async {
    await pumpSheet(tester);
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();
    expect(find.text('Informe a senha'), findsOneWidget);
    verifyNever(() => api.deleteAccount(password: any(named: 'password')));
  });

  testWidgets('senha certa exclui, fecha e avisa', (tester) async {
    when(
      () => api.deleteAccount(password: any(named: 'password')),
    ).thenAnswer((_) async {});
    await pumpSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'secret1',
    );
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    verify(() => api.deleteAccount(password: 'secret1')).called(1);
    expect(find.text('Excluir sua conta'), findsNothing);
    expect(find.text('Conta excluída.'), findsOneWidget);
    expect(controller.isAuthenticated, isFalse);
  });

  testWidgets('senha errada mantém o sheet aberto com a mensagem', (
    tester,
  ) async {
    when(() => api.deleteAccount(password: any(named: 'password'))).thenThrow(
      const CustomAuthException('errors.wrongPassword', 'Senha incorreta'),
    );
    await pumpSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'errada',
    );
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(find.text('Excluir sua conta'), findsOneWidget);
    expect(find.text('Senha incorreta.'), findsOneWidget);
    expect(controller.isAuthenticated, isTrue);
  });

  testWidgets('cancelar fecha sem excluir', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir sua conta'), findsNothing);
    verifyNever(() => api.deleteAccount(password: any(named: 'password')));
  });
}
