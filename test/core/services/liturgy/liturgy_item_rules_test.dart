import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_item_rules.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

void main() {
  LiturgyItem item(LiturgyItemType type, {String? playerId}) =>
      LiturgyItem(id: 'i', type: type, name: 'Item', playerId: playerId);

  test('música toca no player de Hinos, não no player local', () {
    expect(
      LiturgyItemRules.playsInLocalPlayer(item(LiturgyItemType.music)),
      isFalse,
    );
  });

  test('mídias e textos usam o player local', () {
    for (final type in [
      LiturgyItemType.video,
      LiturgyItemType.onlineVideo,
      LiturgyItemType.audio,
      LiturgyItemType.pdf,
      LiturgyItemType.images,
      LiturgyItemType.annotation,
      LiturgyItemType.notice,
      LiturgyItemType.prayer,
    ]) {
      expect(LiturgyItemRules.playsInLocalPlayer(item(type)), isTrue);
      expect(
        LiturgyItemRules.playsInLocalPlayer(item(type, playerId: 'default')),
        isTrue,
      );
    }
  });

  test('player externo escolhido no item sai do player local', () {
    expect(
      LiturgyItemRules.playsInLocalPlayer(
        item(LiturgyItemType.video, playerId: 'vlc'),
      ),
      isFalse,
    );
  });
}
