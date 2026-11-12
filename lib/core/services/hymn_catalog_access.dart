library;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/local/catalog_cache.dart';
import '../../data/datasources/remote/louvorja_api_impl.dart';
import '../../data/repositories/hymn_repository_impl.dart';
import '../constants/api_config.dart';

/// Repositório de hinos fora da aba Hinos (playlists): mesmo índice,
/// mesmo cache em disco e mesma API que a aba usa.
class HymnCatalogAccess {
  static final Map<String, Future<HymnRepositoryImpl>> _repos = {};

  static Future<HymnRepositoryImpl> repository(String languagePrefix) =>
      _repos.putIfAbsent(languagePrefix, () async {
        final api = LouvorjaApiImpl(
          baseUrls: ApiConfig.databaseUrls(),
          filesUrls: ApiConfig.filesUrls(),
          apiToken: const String.fromEnvironment('API_TOKEN', defaultValue: ''),
          languagePrefix: languagePrefix,
        );
        final cache = kIsWeb
            ? CatalogCache.noop()
            : CatalogCache(await getApplicationDocumentsDirectory());
        return HymnRepositoryImpl(api, cache);
      });
}
