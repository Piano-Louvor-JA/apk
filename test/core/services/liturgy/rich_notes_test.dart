import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/rich_notes.dart';

void main() {
  test('sanitiza conteúdo externo e mantém apenas tags e estilos do desktop', () {
    final clean = RichNotes.sanitize(
      '<p onclick="bad()" style="color: #ffee58; position: fixed; text-align: center"><b>Olá</b><script>roubar()</script><img src=x onerror=bad()></p>',
    );
    expect(clean, contains('<b>Olá</b>'));
    expect(clean, contains('color: #ffee58;'));
    expect(clean, contains('text-align: center;'));
    expect(clean, isNot(contains('onclick')));
    expect(clean, isNot(contains('script')));
    expect(clean, isNot(contains('roubar')));
    expect(clean, isNot(contains('<img')));
    expect(clean, isNot(contains('position')));
  });
  test('listas e blocos geram a mesma versão em texto puro do desktop', () {
    expect(
      RichNotes.plainText(
        '<div>Título</div><ol><li>Um</li><li>Dois</li></ol><p>Fim<br>Amém</p>',
      ),
      'Título\n1. Um\n2. Dois\nFim\nAmém',
    );
    expect(
      RichNotes.fromPlainText('A & B\n<literal>'),
      '<div>A &amp; B</div><div>&lt;literal&gt;</div>',
    );
  });
  test('cor do título aceita somente hexadecimal de seis dígitos', () {
    expect(RichNotes.titleColor(' #FFEE58 '), '#ffee58');
    expect(RichNotes.titleColor('red'), isEmpty);
    expect(RichNotes.sanitize('<div><br></div>'), isEmpty);
  });

  test('corpo da anotação: html, depois subtítulo, depois notas', () {
    expect(
      RichNotes.bodyOf(notesHtml: '<b>Oi</b>', subtitle: 'x', notes: 'y'),
      '<b>Oi</b>',
    );
    expect(
      RichNotes.bodyOf(notesHtml: '', subtitle: 'Avisos', notes: 'y'),
      RichNotes.fromPlainText('Avisos'),
    );
    // Anotação com o texto só em notes (o editor abria vazio).
    expect(
      RichNotes.bodyOf(notesHtml: null, subtitle: '', notes: 'lembrete'),
      RichNotes.fromPlainText('lembrete'),
    );
    expect(RichNotes.bodyOf(notesHtml: null, subtitle: '', notes: null), '');
  });
}
