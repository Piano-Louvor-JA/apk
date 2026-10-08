library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/presentation/bible/book_colors.dart';

BibleBook _book(int number, {String? color}) => BibleBook(
  id: number,
  name: 'Livro $number',
  abbreviation: 'Lv',
  chapters: 10,
  bookNumber: number,
  color: color,
);

void main() {
  final light = ThemeData(brightness: Brightness.light);
  final dark = ThemeData(brightness: Brightness.dark);

  group('BookColors paridade web (cores da API)', () {
    test('cor da API vale em AMBOS os temas (web pinta igual)', () {
      final mateus = _book(40, color: '#ff6766'); // evangelhos NT
      expect(BookColors.tone(mateus, light), const Color(0xFFFF6766));
      expect(BookColors.tone(mateus, dark), const Color(0xFFFF6766));
    });

    test('cores canonicas do NT (amostra da API real)', () {
      // Amostra verificada em pt_bible_book (2026-08-15):
      // NT: #ff6766 (evangelhos+atos), #7497ff (cartas), #008c8d,
      //      #b265ff, #ffd140
      final apocalipse = _book(66, color: '#ffd140');
      final romanos = _book(45, color: '#7497ff');
      expect(BookColors.tone(apocalipse, dark), const Color(0xFFFFD140));
      expect(BookColors.tone(romanos, light), const Color(0xFF7497FF));
    });

    test('sem color da API cai no fallback por tone (dark e light)', () {
      final genesis = _book(1); // law
      expect(BookColors.tone(genesis, light), const Color(0xFF1D4ED8));
      expect(BookColors.tone(genesis, dark), const Color(0xFF93C5FD));
    });

    test('background usa cor da API translucida em ambos os temas', () {
      final mateus = _book(40, color: '#ff6766');
      expect(BookColors.background(mateus, light).a, closeTo(0.16, 0.01));
      expect(BookColors.background(mateus, dark).a, closeTo(0.22, 0.01));
    });

    test('selecionado mantem highlight ambar (contraste)', () {
      final mateus = _book(40, color: '#ff6766');
      expect(
        BookColors.tone(mateus, dark, selected: true),
        const Color(0xFFFEF08A),
      );
    });
  });

  group('fallback por tone (restantes) e background selected', () {
    test('history, prophets, gospels, letters e neutral divergem por tema', () {
      final cases = <int, (Color, Color)>{
        10: (const Color(0xFF15803D), const Color(0xFF86EFAC)), // history
        20: (const Color(0xFFA16207), const Color(0xFFFDE68A)), // prophets
        42: (const Color(0xFF7E22CE), const Color(0xFFD8B4FE)), // gospels
      };
      cases.forEach((number, expected) {
        final book = _book(number);
        expect(
          BookColors.tone(book, light),
          expected.$1,
          reason: 'bookNumber $number',
        );
        expect(
          BookColors.tone(book, dark),
          expected.$2,
          reason: 'bookNumber $number',
        );
      });

      // letters (44-66) e neutral (67+) caem no onSurface do tema.
      expect(BookColors.tone(_book(50), light), light.colorScheme.onSurface);
      expect(BookColors.tone(_book(50), dark), dark.colorScheme.onSurface);
      expect(BookColors.tone(_book(70), light), light.colorScheme.onSurface);
      expect(BookColors.tone(_book(70), dark), dark.colorScheme.onSurface);
    });

    test('background sem color por tone — light/dark', () {
      final law = _book(1);
      final bl = BookColors.background(law, light);
      final bd = BookColors.background(law, dark);
      expect(bl.a, closeTo(0.15, 0.01));
      expect(bd.a, closeTo(0.18, 0.01));

      final history = _book(10);
      expect(BookColors.background(history, light).a, closeTo(0.15, 0.01));
      expect(BookColors.background(history, dark).a, closeTo(0.12, 0.01));

      final prophets = _book(20);
      expect(BookColors.background(prophets, light).a, closeTo(0.18, 0.01));
      expect(BookColors.background(prophets, dark).a, closeTo(0.14, 0.01));

      final gospels = _book(42);
      expect(BookColors.background(gospels, light).a, closeTo(0.15, 0.01));
      expect(BookColors.background(gospels, dark).a, closeTo(0.12, 0.01));

      // letters/neutral usam surfaceContainerHigh/Highest direto.
      final neutral = _book(70);
      expect(
        BookColors.background(neutral, light),
        light.colorScheme.surfaceContainerHigh,
      );
      final letters = _book(50);
      expect(
        BookColors.background(letters, dark),
        dark.colorScheme.surfaceContainerHighest,
      );
    });

    test('background selected: âmbar com alpha 0.25/0.4', () {
      final book = _book(1);
      expect(
        BookColors.background(book, light, selected: true).a,
        closeTo(0.25, 0.01),
      );
      expect(
        BookColors.background(book, dark, selected: true).a,
        closeTo(0.40, 0.01),
      );
    });

    test('tone selected light é marrom escuro', () {
      final book = _book(1);
      expect(
        BookColors.tone(book, light, selected: true),
        const Color(0xFF78350F),
      );
    });
  });
}
