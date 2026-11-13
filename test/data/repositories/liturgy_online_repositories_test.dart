import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_link_repository_impl.dart';
import 'package:louvorja_piano_mobile/data/repositories/provai_repository_impl.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/provai_catalog.dart';

class Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String body =
      '<title>Site de teste</title><meta name="description" content="Descrição">';
  bool fail = false;
  String Function(RequestOptions)? answer;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (fail)
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    return ResponseBody.fromString(
      answer?.call(options) ?? body,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class Paths extends PathProviderPlatform {
  Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Adapter adapter;
  late Dio dio;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('liturgy-online');
    PathProviderPlatform.instance = Paths(directory.path);
    adapter = Adapter();
    dio = Dio()..httpClientAdapter = adapter;
  });
  tearDown(() async {
    dio.close();
    await directory.delete(recursive: true);
  });
  test(
    'Vimeo seleciona a maior qualidade pública de download e grava localmente',
    () async {
      adapter.answer = (request) => request.uri.path.endsWith('/config')
          ? '{"request":{"files":{"progressive":[{"height":360,"url":"https://cdn.example/360.mp4"},{"height":1080,"url":"https://cdn.example/1080.mp4"}]}}}'
          : 'video-bytes';
      final file = File('${directory.path}/vimeo.mp4');
      await LiturgyLinkRepositoryImpl(
        dio: dio,
      ).download('https://vimeo.com/123', file.path);
      expect(
        adapter.requests.last.uri.toString(),
        'https://cdn.example/1080.mp4',
      );
      expect(await file.readAsString(), 'video-bytes');
    },
  );
  test(
    'metadados persistem e reabrem sem rede, com identidade de plataforma',
    () async {
      final repo = LiturgyLinkRepositoryImpl(dio: dio);
      final first = await repo.info('https://example.org');
      expect(first.title, 'Site de teste');
      expect(first.description, 'Descrição');
      adapter.fail = true;
      expect(
        (await LiturgyLinkRepositoryImpl(
          dio: dio,
        ).info('https://example.org')).title,
        'Site de teste',
      );
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers['X-Client-Platform'],
        'apk-android',
      );
      expect(adapter.requests.single.headers['X-Client-Version'], isNotEmpty);
    },
  );
  test(
    'vídeo direto baixa sem converter o HTML de uma página em vídeo',
    () async {
      final repo = LiturgyLinkRepositoryImpl(dio: dio);
      final file = File('${directory.path}/video.mp4');
      adapter.body = 'video-bytes';
      await repo.download('https://example.org/video.mp4', file.path);
      expect(await file.readAsString(), 'video-bytes');
      await expectLater(
        repo.download('https://example.org/page', file.path),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'Provai usa catálogo em cache quando a rede falha e reutiliza download existente',
    () async {
      final source = ProvaiCatalog.source('pt', 2026, 4)!;
      adapter.body =
          '<a href="https://bucket.example/11-14-26_Gratidao.mp4">vídeo</a>';
      final repo = ProvaiRepositoryImpl(dio: dio);
      final episodes = await repo.episodes(source);
      expect(episodes.single.title, 'Gratidao');
      adapter.fail = true;
      expect(
        (await ProvaiRepositoryImpl(dio: dio).episodes(source)).single.url,
        episodes.single.url,
      );
      adapter.fail = false;
      adapter.body = 'mp4';
      final path = await repo.download(episodes.single);
      expect(await File(path).readAsString(), 'mp4');
      final count = adapter.requests.length;
      expect(await repo.download(episodes.single), path);
      expect(adapter.requests.length, count);
    },
  );
  test('Provai sem cache informa falha sem inventar episódios', () async {
    adapter.fail = true;
    await expectLater(
      ProvaiRepositoryImpl(
        dio: dio,
      ).episodes(ProvaiCatalog.source('es', 2026, 1)!),
      throwsA(isA<DioException>()),
    );
  });
}
