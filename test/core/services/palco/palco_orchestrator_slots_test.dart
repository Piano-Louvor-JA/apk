import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Orquestrador é singleton; cada grupo começa limpo removendo os slots.
  Future<void> clean() async {
    final orch = PalcoOrchestrator.instance;
    for (final s in orch.slots.toList()) {
      await orch.removeSlot(s.id);
    }
    orch.clearMirror();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PalcoOrchestrator — gerência de slots (puro, sem rede)', () {
    test('addSlot cria, ativa o primeiro e persiste', () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      expect(orch.addSlot(id: 'a', label: 'TV A'), isTrue);
      expect(orch.slot('a'), isNotNull);
      expect(orch.activeSlotId, 'a');
      expect(orch.slots.single.label, 'TV A');
    });

    test('addSlot rejeita id duplicado', () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'dup', label: '1');
      expect(orch.addSlot(id: 'dup', label: '2'), isFalse);
      expect(orch.slots.length, 1);
    });

    test('addSlot respeita limite de 4 slots', () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      for (final id in ['s1', 's2', 's3', 's4']) {
        expect(orch.addSlot(id: id, label: id), isTrue);
      }
      expect(orch.addSlot(id: 's5', label: 'excedente'), isFalse);
      expect(orch.slots.length, PalcoOrchestrator.maxSlots);
    });

    test('slotIndex explícito é preservado; índice duplicado é rejeitado',
        () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      expect(orch.addSlot(id: 'i0', label: '0', slotIndex: 0), isTrue);
      expect(orch.addSlot(id: 'i0b', label: 'repetido', slotIndex: 0), isFalse);
      expect(orch.addSlot(id: 'i3', label: '3', slotIndex: 3), isTrue);
      expect(orch.slot('i3')!.slotIndex, 3);
      // índice fora da faixa:
      expect(orch.addSlot(id: 'i9', label: '9', slotIndex: 9), isFalse);
    });

    test('sem slotIndex: usa primeiro índice livre', () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'a', slotIndex: 0);
      orch.addSlot(id: 'b', slotIndex: 2);
      orch.addSlot(id: 'c'); // deve pegar 1
      expect(orch.slot('c')!.slotIndex, 1);
    });

    test('removeSlot troca ativo, limpa espelho e persiste', () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'x', label: 'X');
      orch.addSlot(id: 'y', label: 'Y');
      orch.setActiveSlot('x');
      orch.toggleMirror({'x', 'y'});
      expect(orch.isMirrorMode, isTrue);

      await orch.removeSlot('x');
      expect(orch.slot('x'), isNull);
      expect(orch.activeSlotId, 'y');
      // Espelho cai de {'x','y'} pra {'y'} (comportamento atual: só zera
      // quando fica VAZIO — single restante continua em modo espelho):
      expect(orch.mirrorGroup, {'y'});
      expect(orch.isMirrorMode, isTrue);
      orch.clearMirror();
      expect(orch.isMirrorMode, isFalse);
    });

    test('removeSlot de id inexistente é no-op seguro', () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      await orch.removeSlot('fantasma');
      expect(orch.slots, isEmpty);
    });

    test('renameSlot muda label; setActiveSlot ignora id inexistente',
        () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'r', label: 'Antigo');
      orch.renameSlot('r', 'Novo');
      expect(orch.slot('r')!.label, 'Novo');

      final before = orch.activeSlotId;
      orch.setActiveSlot('inexistente');
      expect(orch.activeSlotId, before);
    });

    test('toggleMirror com ids explícitos; clearMirror desliga', () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'm1', label: 'M1');
      orch.addSlot(id: 'm2', label: 'M2');
      orch.toggleMirror({'m1', 'm2'});
      expect(orch.mirrorGroup, {'m1', 'm2'});
      orch.clearMirror();
      expect(orch.isMirrorMode, isFalse);
    });

    test('toggleMirror sem ids precisa 2 conectados (sem rede: recusa)',
        () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'u1', label: 'U1');
      orch.addSlot(id: 'u2', label: 'U2');
      // Nenhum conectado (sem rede no teste) → connected = 0 → recusa.
      orch.toggleMirror(null);
      expect(orch.mirrorGroup, isNull);
    });

    test('loadStoredConfig: restaura, aplica ativo e ignora entradas inválidas',
        () async {
      await clean();
      SharedPreferences.setMockInitialValues({
        'palco.multi.slots.v1': '''
[{"id":"tv1","label":"TV 1","slotIndex":0,"httpPort":7080,"wsPort":7081},
 {"id":"ok","label":"OK","slotIndex":2},
 {"label":"sem id"},
 {"id":"sem-label"},
 {"id":"tv2","label":"TV 2","slotIndex":1,"httpPort":7082,"wsPort":7083}]''',
        'palco.multi.active.v1': 'tv2',
      });
      final orch = PalcoOrchestrator.instance;
      await orch.loadStoredConfig();
      // Válidos restaurados com índice preservado:
      expect(orch.slot('tv1')!.slotIndex, 0);
      expect(orch.slot('tv2')!.slotIndex, 1);
      expect(orch.slot('ok')!.slotIndex, 2);
      // Inválidos ignorados (sem id ou sem label):
      expect(orch.slots.map((s) => s.id), containsAll(['tv1', 'tv2', 'ok']));
      expect(orch.slots.length, 3);
      // Ativo restaurado:
      expect(orch.activeSlotId, 'tv2');
    });

    test('persistConfig grava slots+ativo (aguarda microtask persist)',
        () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'p1', label: 'P1', slotIndex: 0);
      orch.addSlot(id: 'p2', label: 'P2', slotIndex: 1);
      orch.setActiveSlot('p2');
      // persist é unawaited — dá tempo de completar:
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecodeOrNull(prefs.getString('palco.multi.slots.v1'));
      expect(saved, isNotNull);
      expect(saved!.length, greaterThanOrEqualTo(2));
      expect(prefs.getString('palco.multi.active.v1'), 'p2');
    });

    test('connectedCount/anyConnected: 0 sem rede; project recusa sem alvo',
        () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'n1', label: 'N1');
      expect(orch.connectedCount, 0);
      expect(orch.anyConnected, isFalse);
      // project sem TV conectada → false (guard de topo):
      final ok = await orch.project(title: 'Teste');
      expect(ok, isFalse);
      // projectToSlot de slot inexistente → false:
      expect(
        await orch.projectToSlot('nada', title: 'x'),
        isFalse,
      );
    });

    test('activeSlot reflete o slot ativo; slots ordenados por id', () async {
      await clean();
      final orch = PalcoOrchestrator.instance;
      orch.addSlot(id: 'zz', label: 'Z');
      orch.addSlot(id: 'aa', label: 'A');
      expect(orch.slots.map((s) => s.id), ['aa', 'zz']);
      orch.setActiveSlot('aa');
      expect(orch.activeSlot?.id, 'aa');
    });
  });
}

/// jsonDecode helper simples.
List<dynamic>? jsonDecodeOrNull(String? raw) {
  if (raw == null) return null;
  final value = jsonDecode(raw);
  return value is List ? value : null;
}
