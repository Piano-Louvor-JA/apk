import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

void main() {
  test('espelha anúncios e preserva configuração no roundtrip', () {
    final state =
        RemoteProtocol.parse(
              jsonEncode({
                'v': 1,
                'type': 'state',
                'player': {
                  'playing': false,
                  'positionMs': 0,
                  'durationMs': 0,
                  'slideIndex': 0,
                  'slideCount': 0,
                  'volume': 80,
                  'canPrevious': false,
                  'canNext': false,
                },
                'announcements': {
                  'activeListId': 'l1',
                  'lists': [
                    {
                      'id': 'l1',
                      'name': 'Avulsa',
                      'items': [
                        {
                          'id': 'a1',
                          'title': 'Aviso',
                          'kind': 'text',
                          'text': 'Reunião',
                          'inCarousel': true,
                        },
                      ],
                    },
                  ],
                  'slideMs': 10000,
                  'loop': true,
                  'status': 'playing',
                  'slideIndex': 1,
                  'slideCount': 4,
                  'previewTitle': 'Aviso',
                  'previewText': 'Reunião',
                },
              }),
            )
            as RemotePlayerState;
    expect(
      state.announcementsModule!.lists.single.items.single.text,
      'Reunião',
    );
    expect(state.announcementsModule!.slideMs, 10000);
    final restored = RemoteProtocol.parse(state.encode()) as RemotePlayerState;
    expect(restored.announcementsModule!.slideCount, 4);
    expect(restored.announcementsModule!.status, 'playing');
  });
  test('comando de carrossel inclui destino e parâmetros reais', () {
    final command = RemoteCommand(
      id: 'a',
      action: RemoteAction.announcementsInclude,
      targetId: 'a1',
      enabled: false,
    );
    final decoded = jsonDecode(command.encode()) as Map;
    expect(decoded['action'], 'announcements.include');
    expect(decoded['targetId'], 'a1');
    expect(decoded['enabled'], isFalse);
  });
}
