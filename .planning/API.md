# API.md — LouvorJA PIANO Flutter

> **Fonte de verdade:** Código-fonte extraído dos repos `pianolouvorja/app` e
> `pianolouvorja/web`. Estes NÃO são palpites — são os endpoints reais em produção hoje.

## Visão Geral

A API atual **NÃO é REST** — é um sistema de catálogo baseado em **arquivos JSON estáticos**
servidos por `https://api.louvorja.com.br`. O app Electron/web consome esses JSONs via
`fetch()` com header `Api-Token`.

**Futuro:** API REST própria documentada em `https://api.louvorja.com.br/documentation`.

### Endpoints Base (produção)

| Variável de Ambiente | URL Default | Função |
|---|---|---|
| `VITE_URL_FILES` | `https://api.louvorja.com.br/file` | Arquivos de mídia (capas, áudio) |
| `VITE_URL_DATABASE` | `https://api.louvorja.com.br/json_db` | Catálogos JSON (hinos, Bíblia, coletâneas) |
| `VITE_API_TOKEN` | *(configurado por ambiente)* | Token de autenticação |

### Autenticação

```
Header: Api-Token: <token>
```

### Estratégia de Retry (já implementada no Electron)

- **429 (Rate Limit):** retry com backoff exponencial (1s → 1.5s → 2.25s...)
- **5xx (Server Error):** retry com mesmo backoff
- **Network Error:** retry (Failed to fetch / NetworkError)
- **Máximo:** 5 tentativas

---

## Catálogos JSON (Endpoints Reais)

Todos servidos de `{VITE_URL_DATABASE}/{filename}?{YYYYMMDD}`

> O sufixo de data é um **cache-buster** — a data atual em formato `YYYYMMDD`.

| Arquivo JSON | Módulo | Tipo | Descrição |
|---|---|---|---|
| `pt_hymnal` | Hinário | `Array<HymnalRow>` | Hinário Adventista (atual) |
| `pt_hymnal_1996` | Hinário | `Array<HymnalRow>` | Hinário Adventista Edição 1996 |
| `pt_categories` | Álbuns | `Array<Category>` | Categorias + coletâneas |
| `album_{id}` | Álbuns | `AlbumRecord` | Músicas de uma coletânea |
| `music_{id}` | Detalhe | `MusicRecord` | Metadados completos, URLs de áudio e letra estruturada |
| `pt_musics` | Busca | `Array<MusicIndexRow>` | Índice global de todas as músicas |
| `pt_bible_book` | Bíblia | `Array<BibleBookRow>` | 66 livros da Bíblia |
| `pt_bible_version` | Bíblia | `Array<BibleVersionRow>` | Versões disponíveis (ARA, NVI, etc.) |
| `bible_{versionId}_{bookId}_{chapter}` | Bíblia | `BibleChapterVerses` | Versículos de um capítulo |

### Coletâneas Excluídas

 hardcoded no Electron:
```typescript
const EXCLUDED_ALBUM_IDS = new Set([712, 629])
```

---

## Schemas dos Catálogos (TypeScript → Dart)

### HymnalRow (Hinário)

```typescript
{
  id_music: number | string
  name?: string
  track?: number | string | null        // número do hino
  duration?: number | string | null     // segundos OU "HH:MM:SS" OU "MM:SS"
  has_instrumental_music?: number | string | boolean | null
  url_instrumental_music?: string | null
}
```

### Category (Coletâneas)

```typescript
{
  id_category?: number | string
  name?: string
  albums?: Array<{
    id_album: number | string
    name?: string
    subtitle?: string
    url_image?: string | null           // capa do álbum
  }>
}
```

### AlbumRecord (Músicas de um álbum)

```typescript
{
  id_album?: number | string
  name?: string
  musics?: Array<HymnalRow>              // mesmo formato do hinário
}
```

### MusicIndexRow (Índice global)

```typescript
{
  id_music: number | string
  name?: string
  track?: number | string | null
  duration?: number | string | null
  has_instrumental_music?: number | string | boolean | null
  url_instrumental_music?: string | null
  albums?: Array<{
    id_album?: number | string
    name?: string
    track?: number | string | null
  }>
  albums_names?: string                  // nomes separados por "·" ou "|"
}
```

### BibleBookRow

```typescript
{
  id_bible_book: number | string
  name: string
  abbreviation: string
  chapters: number | string
  book_number: number | string           // 1-66 (1-39 = AT, 40-66 = NT)
  id_language?: string                   // default: "pt"
}
```

### BibleVersionRow

```typescript
{
  id_bible_version: number | string
  abbreviation: string                   // ex: "ARA", "NVI"
  name: string
  id_language?: string                   // default: "pt"
}
```

### BibleChapterVerses

```typescript
// Objeto chave-valor: número_do_versiculo → texto
{
  "1": "No princípio criou Deus os céus e a terra.",
  "2": "E a terra era sem forma e vazia...",
  // ...
}
```

---

## URLs de Mídia

### Capas de Álbuns

```
GET {VITE_URL_FILES}/{path}
```

Caminhos comuns:
- `/musics/{filename}` — capas de hinos
- `/images/{filename}` — imagens gerais
- `/covers/{filename}` — capas de álbuns

### Áudio (Streaming URL)

```typescript
function resolveMediaUrl(relativePath: string): string {
  // Web:  `{VITE_URL_FILES}/{relativePath}`
  // Desktop: `local://media/{relativePath}`  // arquivo local baixado
}
```

### Padrão de URL de Áudio Instrumental

```typescript
url_instrumental_music  // caminho relativo no servidor de arquivos
```

---

## Parsing de Duração

A duração dos hinos vem em **3 formatos possíveis** — o Flutter precisa tratar todos:

```dart
// Implementar equivalente a parseCatalogDurationMs()
//
// 1. number (segundos):     187.5      → 187500 ms
// 2. "MM:SS":               "3:07"     → 187000 ms
// 3. "HH:MM:SS":            "1:02:03"  → 3723000 ms
int? parseDurationMs(dynamic raw) { ... }
```

---

## API Futura (Planejada)

**URL:** `https://api.louvorja.com.br/documentation`

Quando a API REST própria estiver disponível, o Flutter deve:

1. Manter o cliente JSON atual como **fallback offline**
2. Usar a API REST como **fonte primária** quando online
3. Sincronizar dados da API REST → SQLite (Drift) para uso offline
4. Suportar paginação (API REST provavelmente paginará resultados)
5. Cache de capas/áudio com invalidação via ETag/Last-Modified

### Interface Abstrata (preparar desde já)

```dart
/// Abstract interface para permitir troca de backend sem refactor.
abstract class LouvorjaApiClient {
  Future<List<Hymn>> fetchHymns();
  Future<List<Album>> fetchAlbums();
  Future<List<BibleBook>> fetchBibleBooks();
  Future<List<BibleVersion>> fetchBibleVersions();
  Future<Map<int, String>> fetchChapterVerses(int versionId, int bookId, int chapter);
  Future<String> resolveMediaUrl(String relativePath);
}

/// Implementação atual (JSON estático)
class JsonDbClient implements LouvorjaApiClient { ... }

/// Implementação futura (API REST)
class RestApiClient implements LouvorjaApiClient { ... }
```

---

## Configuração Flutter (equivalente .env)

```dart
// lib/core/constants/api_config.dart
class ApiConfig {
  static const String urlFiles = String.fromEnvironment(
    'LOUVORJA_URL_FILES',
    defaultValue: 'https://api.louvorja.com.br/file',
  );

  static const String urlDatabase = String.fromEnvironment(
    'LOUVORJA_URL_DATABASE',
    defaultValue: 'https://api.louvorja.com.br/json_db',
  );

  static const String apiToken = String.fromEnvironment(
    'LOUVORJA_API_TOKEN',
  );

  static const int maxRetries = 5;
  static const Duration initialRetryDelay = Duration(seconds: 1);
}
```

```bash
# flutter run --dart-define=LOUVORJA_API_TOKEN=...
```

---

## Considerações para Flutter Mobile

1. **Sem CORS** — mobile não tem restrição CORS (diferente do web PWA)
2. **Cache agressivo** — primeira sincronização baixa tudo, depois funciona offline
3. **Retry com Dio** — usar pacote `dio` com `InterceptorsWrapper` para backoff
4. **Cache-buster de data** — manter o padrão `?YYYYMMDD` para invalidar cache CDN
5. **Rate limiting** — a API atual retorna 429; implementar throttling no cliente
6. **Token no header** — `Api-Token` header (não é Bearer/OAuth)
7. **Sem documentação OpenAPI atual** — a API atual é descrita apenas pelo uso no código
