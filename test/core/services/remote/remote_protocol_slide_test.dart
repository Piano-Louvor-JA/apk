import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

const _player =
    '"playing":false,"positionMs":0,"durationMs":0,"volume":0,'
    '"canPrevious":false,"canNext":false';

RemotePlayerState _parse(String json) =>
    RemoteProtocol.parse(json)! as RemotePlayerState;

void main() {
  test('le slides do campo de topo enviado pelo desktop', () {
    final state = _parse(
      '{"v":1,"type":"state","player":{$_player},'
      '"slide":{"index":3,"total":12}}',
    );

    expect(state.slideIndex, 3);
    expect(state.slideCount, 12);
  });

  test('peer antigo com slides dentro de player continua funcionando', () {
    final state = _parse(
      '{"v":1,"type":"state","player":{$_player,'
      '"slideIndex":1,"slideCount":5}}',
    );

    expect(state.slideIndex, 1);
    expect(state.slideCount, 5);
  });

  test('comandos de slide usam o formato aceito pelo desktop', () {
    expect(RemoteAction.slideNext.wire, 'slide:next');
    expect(RemoteAction.slidePrevious.wire, 'slide:prev');
  });
}
