import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

/// Mesmo contrato visual do controle remoto, executado no dispositivo local.
abstract class LocalLiturgyMedia {
  Stream<RemotePlayerState> get states;
  Future<void> open(LiturgyItem item, String language, DateTime date);
  Future<void> send(RemoteCommand command);
  Future<void> updateText(LiturgyItem item);
  Future<void> dispose();
}
