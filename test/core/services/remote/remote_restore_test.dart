import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_connection_store.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';

class MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};
  @override
  dynamic noSuchMethod(Invocation call) {
    final key = call.namedArguments[#key] as String;
    if (call.memberName == #read) return Future<String?>.value(values[key]);
    if (call.memberName == #write) {
      values[key] = call.namedArguments[#value] as String;
      return Future<void>.value();
    }
    return super.noSuchMethod(call);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'armazenamento seguro mantém dados e desconexão manual desativa restauração',
    () async {
      final storage = MemoryStorage();
      final store = RemoteConnectionStore(storage: storage);
      const saved = SavedRemoteConnection(
        host: 'localhost',
        port: 48080,
        token: 'VALID',
      );
      await store.save(saved);
      final other = RemoteConnectionStore(storage: storage);
      expect((await other.read())!.matches(saved), isTrue);
      await other.disableAutoReconnect(
        matching: const SavedRemoteConnection(
          host: 'outro',
          port: 48080,
          token: 'BAD',
        ),
      );
      expect((await other.read())!.autoReconnect, isTrue);
      await other.disableAutoReconnect();
      expect((await other.read())!.autoReconnect, isFalse);
      expect((await other.read())!.token, 'VALID');
      storage.values[RemoteConnectionStore.key] = 'corrompido';
      expect(await other.read(), isNull);
    },
  );

  test(
    'somente autenticação bem-sucedida é salva e restaurada na próxima abertura',
    () async {
      final storage = MemoryStorage();
      final store = RemoteConnectionStore(storage: storage);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      var authenticated = 0;
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((raw) {
          final message = jsonDecode(raw as String) as Map;
          if (message['type'] != 'hello') return;
          if (message['token'] == 'VALID') {
            authenticated++;
            socket.add('{"v":1,"type":"ack","id":"remote-auth","ok":true}');
          } else {
            socket.add('{"v":1,"type":"error","code":"bad_token"}');
          }
        });
      });
      var session = RemoteSession(connectionStore: store);
      addTearDown(() async {
        await session.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      });
      await session.connectDesktop(
        host: '127.0.0.1',
        port: server.port,
        token: 'VALID',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((await store.read())!.token, 'VALID');
      await session.dispose();
      session = RemoteSession(
        connectionStore: RemoteConnectionStore(storage: storage),
      );
      expect(await session.restoreLastDesktopConnection(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(authenticated, 2);
      await session.connectDesktop(
        host: '127.0.0.1',
        port: server.port,
        token: 'INVALID',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((await store.read())!.token, 'VALID');
      expect((await store.read())!.autoReconnect, isTrue);
      await session.disconnect();
      expect(await session.restoreLastDesktopConnection(), isFalse);
    },
  );
}
