import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';

void main() {
  test('normaliza domínio, YouTube, Vimeo e vídeo direto como no desktop', () {
    expect(LiturgyWebTarget.parse('example.org')?.url, 'https://example.org');
    expect(
      LiturgyWebTarget.parse('https://youtu.be/abc_123')?.videoId,
      'abc_123',
    );
    expect(
      LiturgyWebTarget.parse('https://www.youtube.com/shorts/xyz')?.kind,
      'youtube',
    );
    expect(
      LiturgyWebTarget.parse('https://vimeo.com/123')?.embedUrl,
      'https://player.vimeo.com/video/123',
    );
    expect(
      LiturgyWebTarget.parse('https://example.org/clip.mp4')?.kind,
      'direct-video',
    );
  });
  test('não aceita esquemas executáveis e gera HTML com URL escapada', () {
    expect(LiturgyWebTarget.parse('javascript:alert(1)'), isNull);
    expect(LiturgyWebTarget.parse('file:///private'), isNull);
    final html = LiturgyWebTarget.parse(
      'https://example.org/?a=1&b=2',
    )!.projectionHtml;
    expect(html, contains('sandbox='));
    expect(html, contains('&amp;'));
    expect(html, isNot(contains('<script')));
  });
}
