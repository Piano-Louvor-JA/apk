import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/p2p_remote_client.dart';

/// flutter_webrtc em sandbox: createPeerConnection pode não ter implementação
/// nativa (MissingPluginException) — acceptOffer deve retornar null limpo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2pRemoteClient — sandbox sem WebRTC nativo', () {
    test('acceptOffer com JSON quebrado retorna null sem lançar', () async {
      final client = P2pRemoteClient();
      final answer = await client.acceptOffer('{quebrado');
      expect(answer, isNull);
      client.dispose();
    });

    test('acceptOffer com SDP vazio retorna null sem lançar', () async {
      final client = P2pRemoteClient();
      final answer = await client.acceptOffer('{"type":"offer","sdp":""}');
      expect(answer, isNull);
      client.dispose();
    });

    test('isOpen false antes de conectar', () {
      final client = P2pRemoteClient();
      expect(client.isOpen, isFalse);
      client.dispose();
    });

    test('send sem canal é no-op silencioso', () {
      final client = P2pRemoteClient();
      client.send({'action': 'play'});
      client.dispose();
    });

    test('dispose duplo não lança', () {
      final client = P2pRemoteClient();
      client.dispose();
      client.dispose();
    });
  });
}
