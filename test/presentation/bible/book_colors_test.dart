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
}
