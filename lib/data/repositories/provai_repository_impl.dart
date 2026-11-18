import 'package:louvorja_piano_mobile/core/constants/app_version.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/platform_header.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/provai_catalog.dart';
import 'package:louvorja_piano_mobile/domain/repositories/provai_repository.dart';

class ProvaiRepositoryImpl implements ProvaiRepository {
  ProvaiRepositoryImpl({Dio? dio})
    : _http =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 15),
            ),
          ) {
    _http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers.addAll(
            clientPlatformHeaders(version: await AppVersion.version),
          );
          handler.next(options);
        },
      ),
    );
  }
  final Dio _http;
  @override
  Future<List<ProvaiEpisode>> episodes(ProvaiSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'liturgy.provai.${source.language}.${source.year}.${source.quarter}';
    try {
      final response = await _http.get<String>(
        source.url,
        options: Options(
          responseType: ResponseType.plain,
          headers: clientPlatformHeaders(),
        ),
      );
      final episodes = ProvaiCatalog.episodes(response.data ?? '');
      if (episodes.isNotEmpty)
        await prefs.setString(
          key,
          jsonEncode(episodes.map((e) => e.toJson()).toList()),
        );
      return episodes;
    } catch (_) {
      final raw = prefs.getString(key);
      if (raw == null) rethrow;
      return (jsonDecode(raw) as List)
          .map(
            (e) => ProvaiEpisode.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    }
  }

  @override
  Future<String> download(ProvaiEpisode episode) async {
    final directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/liturgy-videos',
    );
    await directory.create(recursive: true);
    final name = Uri.parse(
      episode.url,
    ).pathSegments.last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}/$name');
    if (await file.exists() && await file.length() > 0) return file.path;
    final part = '${file.path}.part';
    try {
      await _http.download(
        episode.url,
        part,
        options: Options(headers: clientPlatformHeaders()),
      );
      await File(part).rename(file.path);
      return file.path;
    } catch (_) {
      final partial = File(part);
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }
}
