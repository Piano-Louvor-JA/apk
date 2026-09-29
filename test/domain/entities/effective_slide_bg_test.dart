import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/domain/entities/custom_lyric_slide.dart';

/// Herança de BG: a imagem do 1º slide vira padrão de todos; slides com
/// BG individual são a exceção (pedido do usuário).
void main() {
  test('slide sem BG próprio herda o BG do slide 0 (padrão)', () {
    final bgs = {0: 'padrao.png'};
    expect(effectiveSlideBg(bgs, 1), 'padrao.png');
    expect(effectiveSlideBg(bgs, 5), 'padrao.png');
  });

  test('slide com BG individual sobrepõe o padrão (exceção)', () {
    final bgs = {0: 'padrao.png', 2: 'especial.png'};
    expect(effectiveSlideBg(bgs, 2), 'especial.png');
    expect(effectiveSlideBg(bgs, 1), 'padrao.png');
  });

  test('sem BG no slide 0: sem herança — todos nulos exceto próprios', () {
    final bgs = <int, String>{2: 'especial.png'};
    expect(effectiveSlideBg(bgs, 0), isNull);
    expect(effectiveSlideBg(bgs, 1), isNull);
    expect(effectiveSlideBg(bgs, 2), 'especial.png');
  });

  test('nenhum BG escolhido: tudo nulo (fundo padrão do app)', () {
    expect(effectiveSlideBg(<int, String>{}, 0), isNull);
    expect(effectiveSlideBg(<int, String>{}, 3), isNull);
  });

  test('slide 0 sempre usa o próprio (nunca herda de si)', () {
    final bgs = {0: 'padrao.png'};
    expect(effectiveSlideBg(bgs, 0), 'padrao.png');
  });
}
