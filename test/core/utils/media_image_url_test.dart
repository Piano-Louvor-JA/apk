import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/utils/media_image_url.dart';

void main() {
  test('fundo absoluto do catálogo não recebe prefixo da API', () {
    expect(
      MediaImageUrl.resolve(
        'https://files.louvorja.com.br/images/hasd_599.jpg',
        'http://10.0.2.2:3100/file',
      ),
      'https://files.louvorja.com.br/images/hasd_599.jpg',
    );
  });
  test('fundo relativo usa base de arquivos sem barra duplicada', () {
    expect(
      MediaImageUrl.resolve('/images/capa.jpg', 'http://localhost/file/'),
      'http://localhost/file/images/capa.jpg',
    );
    expect(
      MediaImageUrl.resolve('images/Paz e Luz.jpg', 'https://example.org/file'),
      'https://example.org/file/images/Paz%20e%20Luz.jpg',
    );
  });
  test('capa local de hinário permanece asset', () {
    expect(
      MediaImageUrl.resolve(
        'asset:assets/images/library/hymnal.jpeg',
        'https://example.org/file',
      ),
      'asset:assets/images/library/hymnal.jpeg',
    );
  });
}
