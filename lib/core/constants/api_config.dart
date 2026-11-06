library;

/// Configuracao central da API (API.md — Configuracao Flutter).
///
/// TUDO vem de ambiente (--dart-define) — zero hardcoded, zero default.
/// A referencia dos valores mora no .env/CI de cada build:
///   flutter build apk --release \
///     --dart-define=LOUVORJA_URL_DATABASE=https://api.pianolouvorja.com.br/json_db \
///     --dart-define=LOUVORJA_URL_FILES=https://api.pianolouvorja.com.br/file \
///     --dart-define=LOUVORJA_FALLBACK_URLS=https://api.louvorja.com.br,https://api.louvorja.workers.dev
///
/// FALLBACK (RF: app sempre com onde fazer requisicao):
/// Se a API primaria cair, o app tenta os hosts de LOUVORJA_FALLBACK_URLS
/// (virgula = separador). Env vazia = sem fallback. Redundancia futura da
/// nossa API = incluir o host na lista do build, sem tocar em codigo.
class ApiConfig {
  /// ADR-11 (SPEC piano-bundle-sync v1.2.0): origem de `/db/*` (manifest +
  /// bundles) é PRÓPRIA e NUNCA derivada de [urlDatabase] — quem publica
  /// /db/* é o UPSTREAM (api.louvorja.com.br), não a nossa API (/json_db).
  /// Default público documentado; override apenas via --dart-define.
  static const String defaultBundlesOrigin = 'https://api.louvorja.com.br';

  static const String _bundlesUrlRaw = String.fromEnvironment(
    'LOUVORJA_URL_BUNDLES',
  );

  /// Sem dart-define = string vazia (sem base primária).
  static const String urlDatabase = String.fromEnvironment(
    'LOUVORJA_URL_DATABASE',
  );

  static const String urlFiles = String.fromEnvironment(
    'LOUVORJA_URL_FILES',
  );

  static const String _fallbackUrlsRaw = String.fromEnvironment(
    'LOUVORJA_FALLBACK_URLS',
  );

  static const String apiToken = String.fromEnvironment(
    'API_TOKEN',
  );

  /// Host da API primaria, derivado de [urlDatabase] (mesma origem do json_db).
  /// Null quando nao ha base primaria configurada.
  static String? get primaryHost {
    final uri = Uri.tryParse(urlDatabase);
    return (uri != null && uri.hasScheme && urlDatabase.isNotEmpty)
        ? uri.origin
        : null;
  }

  /// APIs de reserva (fallback), em ordem de prioridade, da env
  /// LOUVORJA_FALLBACK_URLS (virgula = separador). A primaria NAO esta
  /// aqui — o fallback so entra quando ela falha.
  static List<String> get fallbackHosts => _fallbackUrlsRaw
      .split(',')
      .map((h) => h.trim())
      .where((h) => h.isNotEmpty)
      .toList();

  /// Hosts candidatos pra database/json_db: primaria (se houver) + fallbacks.
  /// Usado por quem precisa tentar hosts em cascata (LouvorjaApiImpl).
  static List<String> databaseUrls() => [
    if (urlDatabase.isNotEmpty) urlDatabase,
    for (final host in fallbackHosts) '$host/json_db',
  ];

  /// Hosts candidatos pra files: primaria (se houver) + fallbacks.
  static List<String> filesUrls() => [
    if (urlFiles.isNotEmpty) urlFiles,
    for (final host in fallbackHosts) '$host/file',
  ];

  /// Origens candidatas pra /db/* (bundles ADR-11): env própria
  /// LOUVORJA_URL_BUNDLES, senão o default público upstream. NUNCA contém
  /// a origem de [urlDatabase] nem dos fallbacks de database/files — /db/*
  /// não existe na nossa API e o fallback legado não é origem de bundles.
  static List<String> bundlesUrls() => [
    if (_bundlesUrlRaw.trim().isNotEmpty) _bundlesUrlRaw.trim(),
    defaultBundlesOrigin,
  ];
}
