import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/presentation/custom/moderation/blocked_authors_page.dart';
import 'package:louvorja_piano_mobile/presentation/custom/moderation/collection_moderation.dart';

/// Diálogos de denúncia/bloqueio e lista de bloqueados (App Store 1.2).
void main() {
  group('denúncia', () {
    testWidgets('exige um motivo e devolve motivo + detalhes', (tester) async {
      String? reason;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    reason = await showReportCollectionDialog(
                      context,
                      collectionName: 'Hinos',
                    ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Denunciar "Hinos"'), findsOneWidget);
      final submit = find.widgetWithText(FilledButton, 'Denunciar');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);

      await tester.tap(find.text('Spam ou propaganda'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'link de loja');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(reason, 'Spam ou propaganda: link de loja');
    });

    testWidgets('cancelar devolve null', (tester) async {
      String? reason = 'x';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    reason = await showReportCollectionDialog(
                      context,
                      collectionName: 'Hinos',
                    ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(reason, isNull);
    });
  });

  group('bloqueio', () {
    testWidgets('confirmar → true', (tester) async {
      bool? ok;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => ok = await showBlockAuthorDialog(
                  context,
                  authorName: 'Beto',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Bloquear Beto?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
      await tester.pumpAndSettle();
      expect(ok, isTrue);
    });

    testWidgets('cancelar → false', (tester) async {
      bool? ok;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => ok = await showBlockAuthorDialog(
                  context,
                  authorName: 'Beto',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(ok, isFalse);
    });
  });

  group('BlockedAuthorsPage', () {
    CustomCatalogApiImpl apiWith(List<String> log, {bool failList = false}) {
      return CustomCatalogApiImpl(
        fetch: (method, url, {body, bearerToken}) async {
          log.add('$method $url');
          if (method == 'GET') {
            if (failList) throw Exception('offline');
            return {
              'data': [
                {'id_user': 9, 'displayName': 'Beto'},
              ],
            };
          }
          return '';
        },
        apiBaseUrl: 'https://api.test',
        filesBaseUrl: 'https://api.test/file',
      );
    }

    testWidgets('lista e desbloqueia', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: BlockedAuthorsPage(api: apiWith(log), bearerToken: 'tok'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Beto'), findsOneWidget);

      await tester.tap(find.text('Desbloquear'));
      await tester.pumpAndSettle();

      expect(log.last, 'DELETE https://api.test/v1/custom/blocks/9');
      expect(find.text('Beto desbloqueado.'), findsOneWidget);
      expect(find.text('Você não bloqueou ninguém.'), findsOneWidget);
    });

    testWidgets('erro ao carregar mostra mensagem', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlockedAuthorsPage(
            api: apiWith([], failList: true),
            bearerToken: 'tok',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível carregar. Tente novamente.'),
        findsOneWidget,
      );
    });
  });
}
