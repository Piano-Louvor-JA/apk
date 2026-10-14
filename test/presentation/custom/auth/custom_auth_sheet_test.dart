import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_sheet.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements CustomAuthApiImpl {}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Future<BuildContext> _pump(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  late _MockApi api;

  setUp(() {
    api = _MockApi();
  });

  Future<void> pumpSheet(WidgetTester tester, CustomAuthController c) async {
    await tester.pumpWidget(_host(CustomAuthSheet(controller: c)));
    await tester.pump();
  }

  group('CustomAuthSheet — modo login', () {
    testWidgets('renderiza campos email/senha sem campo nome', (tester) async {
      await pumpSheet(tester, CustomAuthController(api));
      expect(find.text('Entrar'), findsWidgets);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Senha'), findsOneWidget);
      expect(find.text('Seu nome'), findsNothing);
      expect(find.text('Não tenho conta — criar'), findsOneWidget);
    });

    testWidgets('validação: email sem @ e senha vazia bloqueiam submit',
        (tester) async {
      await pumpSheet(tester, CustomAuthController(api));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'sem-arroba',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();
      expect(find.text('E-mail inválido'), findsOneWidget);
      expect(find.text('Informe a senha'), findsOneWidget);
      verifyNever(
        () => api.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('login com sucesso → sheet fecha com true', (tester) async {
      final context = await _pump(tester);
      when(
        () => api.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => CustomSession(
          token: 'tok',
          user: const CustomUser(idUser: 1, email: 'a@b.com', displayName: 'A'),
        ),
      );

      final result = CustomAuthSheet.show(context, CustomAuthController(api));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'senha123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
      verify(
        () => api.login(email: 'a@b.com', password: 'senha123'),
      ).called(1);
    });

    testWidgets('login falho com invalidCredentials → snackbar traduzida',
        (tester) async {
      await pumpSheet(tester, CustomAuthController(api));
      when(
        () => api.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const CustomAuthException('errors.invalidCredentials', 'x'),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'errada',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();
      expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
    });

    testWidgets('login falho com erro desconhecido → mensagem genérica',
        (tester) async {
      await pumpSheet(tester, CustomAuthController(api));
      when(
        () => api.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const CustomAuthException('errors.alien', 'x'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'x',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();
      expect(find.text('Não foi possível entrar. Tente novamente.'),
          findsOneWidget);
    });
  });

  group('CustomAuthSheet — modo registro', () {
    testWidgets('alternar para criar conta mostra campo nome e valida',
        (tester) async {
      await pumpSheet(tester, CustomAuthController(api));
      await tester.tap(find.text('Não tenho conta — criar'));
      await tester.pump();

      expect(find.text('Criar conta'), findsWidgets);
      expect(find.text('Seu nome'), findsOneWidget);
      expect(find.text('Mínimo de 8 caracteres'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Seu nome'),
        '',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'curta',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await tester.pump();
      expect(find.text('Informe seu nome'), findsOneWidget);
      expect(find.text('Mínimo de 8 caracteres'), findsNWidgets(2));
    });

    testWidgets('registro com sucesso → fecha com true', (tester) async {
      final context = await _pump(tester);
      when(
        () => api.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer(
        (_) async => CustomSession(
          token: 'tok2',
          user: const CustomUser(idUser: 2, email: 'r@x.com', displayName: 'R'),
        ),
      );

      final result = CustomAuthSheet.show(context, CustomAuthController(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Não tenho conta — criar'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Seu nome'),
        'Rafael',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'r@x.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'senha12345',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
      verify(
        () => api.register(
          email: 'r@x.com',
          password: 'senha12345',
          displayName: 'Rafael',
        ),
      ).called(1);
    });

    testWidgets('registro com email em uso → snackbar específica',
        (tester) async {
      await pumpSheet(tester, CustomAuthController(api));
      when(
        () => api.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenThrow(const CustomAuthException('errors.emailInUse', 'x'));
      await tester.tap(find.text('Não tenho conta — criar'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Seu nome'),
        'Alguém',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'usado@x.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'senha12345',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await tester.pump();
      expect(find.text('Este e-mail já está cadastrado.'), findsOneWidget);
    });

    testWidgets('voltar para login troca os textos', (tester) async {
      await pumpSheet(tester, CustomAuthController(api));
      await tester.tap(find.text('Não tenho conta — criar'));
      await tester.pump();
      await tester.tap(find.text('Já tenho conta — entrar'));
      await tester.pump();
      expect(find.text('Seu nome'), findsNothing);
      expect(find.text('Não tenho conta — criar'), findsOneWidget);
    });
  });
}
