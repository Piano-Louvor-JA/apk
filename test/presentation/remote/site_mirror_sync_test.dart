import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/presentation/remote/site_mirror_sync.dart';

void main() {
  late List<String> sent;
  late List<double> scrolls;
  late SiteMirrorSync sync;

  setUp(() {
    sent = [];
    scrolls = [];
    sync = SiteMirrorSync(navigate: sent.add, scroll: scrolls.add);
  });

  // testWidgets controla o relógio: pump(duração) dispara os timers.
  Future<void> elapse(WidgetTester tester, Duration d) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(d);
  }

  testWidgets(
    'ao abrir leva o desktop para a pagina atual, com nova tentativa',
    (tester) async {
      sync.urlChanged('https://x.org/a');
      sync.markOpened();
      expect(sent, isEmpty, reason: 'o desktop ainda esta abrindo o site');

      await elapse(tester, const Duration(milliseconds: 1500));
      expect(sent, ['https://x.org/a']);

      await elapse(tester, const Duration(seconds: 2));
      expect(sent, ['https://x.org/a', 'https://x.org/a']);
      sync.dispose();
    },
  );

  testWidgets('aberto, cada pagina nova vai para o desktop uma vez', (
    tester,
  ) async {
    sync.markOpened();
    await elapse(tester, const Duration(seconds: 4));

    sync.urlChanged('https://x.org/b');
    sync.urlChanged('https://x.org/b');
    sync.urlChanged('https://x.org/c');
    expect(sent, ['https://x.org/b', 'https://x.org/c']);
    sync.dispose();
  });

  testWidgets('fechar cancela as tentativas pendentes', (tester) async {
    sync.urlChanged('https://x.org/a');
    sync.markOpened();
    sync.dispose();
    await elapse(tester, const Duration(seconds: 5));
    expect(sent, isEmpty);
  });

  testWidgets('rolagem vai no maximo a cada 150 ms, sempre com a ultima', (
    tester,
  ) async {
    sync.markOpened();
    sync.scrollChanged(0.1);
    sync.scrollChanged(0.2);
    sync.scrollChanged(0.3);
    expect(scrolls, [0.1], reason: 'a primeira vai na hora');

    await elapse(tester, const Duration(milliseconds: 150));
    expect(scrolls, [0.1, 0.3], reason: 'a ultima posicao nao se perde');

    await elapse(tester, const Duration(milliseconds: 300));
    expect(scrolls, [0.1, 0.3]);
    sync.dispose();
  });

  test('rolagem antes de abrir no desktop fica so no celular', () {
    sync.scrollChanged(0.4);
    expect(scrolls, isEmpty);
  });
}
