import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/settings/widgets/remote/remote_section.dart';

class _Session extends RemoteSession {
  int? portUsed;
  @override
  Future<bool> connectDesktop({
    required String host,
    required int port,
    required String token,
  }) async {
    portUsed = port;
    return false;
  }
}

void main() {
  for (final entry in {
    '192.168.1.20': 48080,
    '192.168.1.20:7071': 7071,
  }.entries) {
    testWidgets('endereço ${entry.key} conecta na porta ${entry.value}', (
      tester,
    ) async {
      final session = _Session();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RemoteSection(session: session)),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('remote-host')), entry.key);
      await tester.enterText(find.byKey(const Key('remote-token')), 'AABBCCDD');
      await tester.pump();
      await tester.tap(find.byKey(const Key('remote-connect')));
      await tester.pump();
      expect(session.portUsed, entry.value);
      expect(tester.takeException(), isNull);
    });
  }
}
