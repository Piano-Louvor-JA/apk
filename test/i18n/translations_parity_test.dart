// Testes de i18n: paridade estrutural dos JSON de traducao + RTL nativo p/ ar.
//
// Paridade: todos os locales de assets/translations devem ter EXATAMENTE o
// mesmo conjunto de chaves de en.json (fonte), com os mesmos placeholders
// {curly} em cada valor. Isso evita KeyError em runtime no easy_localization.
//
// RTL: Flutter deriva Directionality do locale no MaterialApp/WidgetsApp;
// Locale('ar') deve resolver para TextDirection.rl e os demais para .ltr.
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui show TextDirection;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

typedef TextDirection = ui.TextDirection;

const kSourceFile = 'en';

/// Locales validos suportados pelo app (ordem do main.dart).
const kSupportedLocales = [
  'pt-BR', 'en', 'es', 'ru', 'uk', 'fr', 'ja', 'ko', 'zh', 'tr', 'ar', 'hi',
  'it', 'nl', 'pl',
];

List<String> _assetTranslationLocales() {
  final dir = io.Directory('assets/translations');
  return dir
      .listSync()
      .whereType<io.File>()
      .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
      .where(kSupportedLocales.contains)
      .toList()
    ..sort();
}

Map<String, dynamic> _flat(Map<String, dynamic> raw, [String prefix = '']) {
  final out = <String, dynamic>{};
  raw.forEach((k, v) {
    final key = prefix.isEmpty ? k : '$prefix.$k';
    if (v is Map<String, dynamic>) {
      out.addAll(_flat(v, key));
    } else {
      out[key] = v;
    }
  });
  return out;
}

Map<String, String> _loadFlat(String locale) {
  final raw =
      jsonDecode(io.File('assets/translations/$locale.json').readAsStringSync())
          as Map<String, dynamic>;
  return _flat(raw).map((k, v) => MapEntry(k, v.toString()));
}

/// Extrai placeholders {name} de um valor de traducao, ordenados.
List<String> placeholders(String s) {
  final re = RegExp(r'\{[a-zA-Z]+\}');
  return re.allMatches(s).map((m) => m.group(0)!).toList()..sort();
}

void main() {
  final en = _loadFlat(kSourceFile);
  final locales = _assetTranslationLocales();

  test('locale fonte (en) existe e nao esta vazio', () {
    expect(en, isNotEmpty);
  });

  test('os 15 idiomas suportados tem arquivo de traducao', () {
    for (final l in kSupportedLocales) {
      expect(locales, contains(l), reason: 'faltando assets/translations/$l.json');
    }
    expect(locales, hasLength(15));
  });

  for (final locale in locales) {
    if (locale == kSourceFile) continue;
    group('paridade $locale vs en', () {
      final other = _loadFlat(locale);

      test('0 chaves missing', () {
        final missing = en.keys.toSet().difference(other.keys.toSet());
        expect(missing, isEmpty, reason: 'chaves ausentes em $locale: $missing');
      });

      test('0 chaves extra', () {
        final extra = other.keys.toSet().difference(en.keys.toSet());
        expect(extra, isEmpty, reason: 'chaves extras em $locale: $extra');
      });

      test('placeholders identicos em cada valor', () {
        for (final key in en.keys) {
          expect(
            placeholders(other[key]!),
            placeholders(en[key]!),
            reason: 'placeholder divergente em $locale → $key',
          );
        }
      });
    });
  }

  testWidgets('Locale(ar) resolve Directionality RTL nativo', (tester) async {
    // Directionality vem do WidgetsApp/MaterialApp (localeResolutionCallback
    // padrao), nao do easy_localization — testamos direto o mecanismo Flutter.
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en'),
          Locale('es'),
          Locale('ar'),
        ],
        locale: const Locale('ar'),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(Directionality.of(captured), TextDirection.rtl);
  });

  testWidgets('Locale(en) permanece LTR', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(Directionality.of(captured), TextDirection.ltr);
  });

  test('glossario BARRA: liturgy em ar usa termo cristo formal e hi adventista',
      () {
    final arLit = _loadFlat('ar');
    // الطقس الكنسي = "o rito/ordem eclesiastico" (cristao formal), nao
    // "شعائر" (ritual generico/laico).
    expect(arLit['liturgy.title'], 'الطقس الكنسي');
    expect(arLit['nav.liturgy'], 'الطقس الكنسي');

    final hiLit = _loadFlat('hi');
    // उपासना क्रम = "ordem de adoracao" — registro formal usado no contexto
    // adventista de fala hindi; "पूजा" seria registro generico/nao-cristao.
    expect(hiLit['liturgy.title'], 'उपासना क्रम');
  });

  test('marca "Piano LouvorJA"/"LouvorJA PIANO" permanece no alfabeto latino',
      () {
    for (final locale in locales) {
      final flat = _loadFlat(locale);
      expect(flat['app.name'], 'LouvorJA PIANO',
          reason: 'app.name deve ser marca latina em $locale');
      // Mencao ao produto em stage.waiting preservada.
      expect(flat['stage.waiting']!.contains('LouvorJA'), isTrue,
          reason: 'stage.waiting deve citar LouvorJA em $locale');
    }
  });
}
