import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_file_name.dart';

const id = 'JHXM432zwwo';

void main() {
  test('mesma regra do desktop: sem acento nem símbolo, ID no fim', () {
    expect(
      youtubeFileName('ADORADORES 5 - ÉS O AR QUE EU RESPIRO (LETRA)', id),
      'ADORADORES 5 ES O AR QUE EU RESPIRO LETRA_$id.mp4',
    );
    expect(
      youtubeFileBase('Arautos do Rei | 60 Anos', id),
      'Arautos do Rei 60 Anos_$id',
    );
    expect(sanitizeYoutubeTitle('a<b>c:d"e/f\\g|h?i*j'), 'a b c d e f g h i j');
    expect(sanitizeYoutubeTitle('../../etc/passwd'), 'etc passwd');
    expect(sanitizeYoutubeTitle('Louvor 🙏 ção Ñ ü'), 'Louvor cao N u');
  });

  test('corta em 80 e sem título fica só o ID', () {
    expect(sanitizeYoutubeTitle('x' * 200), hasLength(youtubeFileTitleMax));
    expect(sanitizeYoutubeTitle('${'a' * 79} bbbb'), 'a' * 79);
    expect(youtubeFileBase('!!!', id), id);
    expect(youtubeFileBase(null, id), id);
    expect(youtubeFileBase('賛美歌', id), id);
    expect(youtubeFileBase(id, id), id);
  });

  test('parte editável: o que vem antes do _ID', () {
    expect(
      editableYoutubeTitle('Arautos do Rei_$id.mp4', id),
      'Arautos do Rei',
    );
    expect(editableYoutubeTitle('$id.mp4', id), '');
    expect(editableYoutubeTitle('Outro nome.mp4', id), 'Outro nome');
    expect(editableYoutubeTitle('Sem extensao', id), 'Sem extensao');
    expect(editableYoutubeTitle(null, id), '');
  });
}
