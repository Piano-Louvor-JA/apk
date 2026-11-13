import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'package:louvorja_piano_mobile/data/repositories/local_liturgy_media_impl.dart';
import 'local_liturgy_player.dart';

final localLiturgyPresence = RemotePlayerPresence();
final localLiturgyMedia = LocalLiturgyMediaImpl();
final localLiturgyPlayer = LocalLiturgyPlayer(localLiturgyMedia);
