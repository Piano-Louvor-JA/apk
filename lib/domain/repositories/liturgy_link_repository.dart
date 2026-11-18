import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_link_info.dart';

abstract class LiturgyLinkRepository {
  Future<LiturgyLinkInfo> info(String url);
  Future<void> download(
    String url,
    String destination, {
    void Function(int, int)? onProgress,
  });
}
