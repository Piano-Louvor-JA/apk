import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_page.dart';

void main() {
  group('bookGridHeight (grade de livros com 2 linhas visíveis)', () {
    test('altura = 2 quadrados + 1 espaço entre as linhas', () {
      // 4 colunas, espaço 6: quadrado = (378 - 18) / 4 = 90
      expect(bookGridHeight(378), 90 * 2 + 6);
    });

    test('largura 0 (painel animando) não gera altura negativa', () {
      expect(bookGridHeight(0), 0);
    });

    test('largura menor que os espaços não gera altura negativa', () {
      expect(bookGridHeight(10), 0);
    });

    test('largura infinita não gera altura infinita', () {
      expect(bookGridHeight(double.infinity), 0);
    });
  });
}
