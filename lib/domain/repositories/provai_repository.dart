import 'package:louvorja_piano_mobile/core/services/liturgy/provai_catalog.dart';

abstract interface class ProvaiRepository {
  Future<List<ProvaiEpisode>> episodes(ProvaiSource source);
  Future<String> download(ProvaiEpisode episode);
}
