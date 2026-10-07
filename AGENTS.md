# AGENTS.md — LouvorJA PIANO Flutter

> Guia para AI agents (Claude Code, Codex, Cursor, Hermes) trabalharem
> neste projeto. **LEIA ANTES DE ESCREVER QUALQUER CÓDIGO.**
>
> Referências obrigatórias: [SPEC.md](./SPEC.md) · [PLAN.md](./PLAN.md) ·
> [CONTEXT.md](./CONTEXT.md)

---

## Identidade do Projeto

| Campo | Valor |
|-------|-------|
| **Nome** | LouvorJA PIANO Mobile |
| **Repo** | `github.com/pianolouvorja/mobile` (a criar) |
| **Stack** | Flutter 3.22+ / Dart 3.4+ |
| **Arquitetura** | Clean Architecture (data/domain/presentation) + BLoC |
| **Licença** | MIT (alinhado com OSS) |
| **Autor** | Ezequias Fonseca (mantenedor original) |
| **Colaborador** | Rafael Zendron |
| **AppId** | `com.louvorja.piano.mobile` |

---

## Regras de Ouro (NUNCA quebrar)

1. **NÃO portar código Electron direto.** Este é um app NOVO em Flutter/Dart.
   Use o desktop como REFERÊNCIA de domínio (entidades, regras de negócio),
   nunca como código para copiar.

2. **TDD é obrigatório.** Escreva o teste ANTES da implementação.
   Red → Green → Refactor. Sem exceções.

3. **Qualidade de teste completa.** Coverage **100%** SEM mutantes sobreviventes
   (mutation testing — todo mutante sobrevivente é lacuna de asserção: fortalecer o
   teste até matá-lo). Camadas obrigatórias conforme couber na stack:
   **unitários** (TDD, `bloc_test` para BLoCs, `mocktail` para mocks), **golden tests**
   para widgets, **integração** (fluxos reais: persistência, sync offline, API), e
   **E2E** (jornadas do usuário ponta a ponta). Todo bug fix vem com o teste que
   reproduz o bug.

4. **`flutter analyze` sem warnings.** Configurado com `--fatal-infos`.
   Se o CI falhar em analyze, o PR não entra.

5. **Um PR por task do PLAN.md.** NUNCA misturar tasks. Cada PR referencia
   a task (ex: `feat(hymns): task 2.6 - HymnsPage com BLoC`).

6. **Commits em português.** Mensagens: `tipo(escopo): descrição`.
   Ex: `feat(hymns): adiciona busca com debounce 300ms`.

7. **Sem dados pessoais.** O app não coleta nem armazena dados pessoais.
   LGPD compliant por design. Se uma feature parecer exigir dados pessoais,
   Pare e pergunte.

8. **Design system existente — NÃO inventar tokens.** O design system completo
   já existe em `pianolouvorja/app` e `pianolouvorja/web` (`src/design-system/`).
   O arquivo **DESIGN-TOKENS.md** tem a tradução completa para Flutter.
   NUNCA hardcodar cores — sempre via `Theme.of(context)`.
   A assimetria de borda (TL+BR arredondados, TR+BL retos) é obrigatória.

9. **Offline-first.** Toda feature deve funcionar sem internet após o
   primeiro download do catálogo. Network é camada de sync, não de uso.

10. **Português primeiro.** Código, comentários e docs em PT-BR.
    Nomes de variáveis/classes em inglês (convenção Dart).

11. **API via interface abstrata.** NUNCA chamar `fetch()` ou `dio.get()` direto
    em BLoCs ou widgets. Sempre via `LouvorjaApiClient` (ver [API.md](./API.md)).
    Isso permite trocar a API JSON estática atual pela REST futura sem refactor.

12. **Tabler Icons.** NUNCA usar `Icons` do Material ou `CupertinoIcons`.
    Sempre `TablerIcons.` (mesma lib do Electron/web, v3.45.0).

---

## Estrutura de Pastas

```
lib/
├── app/                        # App root
│   ├── app.dart                # MaterialApp.router
│   ├── router.dart             # go_router config
│   └── theme/
│       ├── app_theme.dart      # ThemeData light + dark
│       └── app_colors.dart     # Paleta de cores
├── core/                       # Utilities compartilhadas
│   ├── constants/              # URLs, tamanhos, durações
│   ├── errors/                 # DomainException, Failure types
│   ├── network/                # Dio client + interceptors
│   └── utils/                  # Helpers (date, string, etc)
├── data/                       # Data layer (implementações)
│   ├── datasources/
│   │   ├── local/              # Drift database + tables
│   │   └── remote/             # Dio API client
│   ├── models/                 # DTOs (freezed + json_serializable)
│   └── repositories/           # Repository implementations
├── domain/                     # Domain layer (contratos)
│   ├── entities/               # Business objects (freezed)
│   ├── repositories/           # Abstract interfaces
│   └── usecases/               # Use cases (single responsibility)
├── presentation/               # UI layer
│   ├── home/                   # Home page + bloc
│   ├── hymns/                  # Hymns pages + bloc
│   ├── liturgy/                # Liturgy pages + bloc
│   ├── timer/                  # Timer/countdown pages + bloc
│   ├── schedule/               # Schedule pages + bloc
│   ├── search/                 # Global search
│   ├── settings/               # Settings
│   └── shared/                 # Design system widgets
└── main.dart                   # Entry point + DI setup

test/                           # Espelha lib/ (unit tests)
integration_test/               # E2E tests
assets/
├── translations/               # pt-BR.json, en.json, es.json
├── icons/                      # Ícones do app
└── images/                     # Imagens estáticas
```

---

## Convenções de Código

### Nomenclatura

| Elemento | Convenção | Exemplo |
|----------|-----------|---------|
| Classes | PascalCase | `HymnRepository` |
| Variáveis | camelCase | `albumId` |
| Constantes | lowerCamelCase | `defaultTimeout` |
| Arquivos | snake_case | `hymn_repository.dart` |
| Enums | PascalCase | `AlbumCategory` |
| BLoC events | PascalCase + verbo | `HymnsLoadRequested` |
| BLoC states | PascalCase + estado | `HymnsLoadSuccess` |

### Imports (ordem obrigatória)

```dart
// 1. Dart SDK
import 'dart:async';

// 2. Flutter
import 'package:flutter/material.dart';

// 3. Packages externos
import 'package:flutter_bloc/flutter_bloc.dart';

// 4. Projeto (alias para clareza)
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

// 5. Arquivos relativos
import 'bloc/hymns_bloc.dart';
```

### BLoC Pattern (obrigatório)

Cada feature tem exatamente:
```
feature/
├── feature_page.dart           # Widget (UI)
├── bloc/
│   ├── feature_bloc.dart       # BLoC
│   ├── feature_event.dart      # Events (freezed)
│   └── feature_state.dart      # States (freezed)
└── widgets/                    # Sub-widgets específicos
```

**Estados seguem o padrão:**
```dart
// SEMPRE começa com: Initial, Loading, Success, Error
@freezed
class HymnsState with _$HymnsState {
  const factory HymnsState.initial() = _Initial;
  const factory HymnsState.loading() = _Loading;
  const factory HymnsState.success({required List<Hymn> hymns}) = _Success;
  const factory HymnsState.error({required String message}) = _Error;
}
```

### Repositório Pattern

```dart
// Domain (interface) — domain/repositories/
abstract class HymnRepository {
  Future<List<Hymn>> getHymnsByAlbum(String albumId);
  Future<List<Hymn>> searchHymns(String query);
}

// Data (implementação) — data/repositories/
class HymnRepositoryImpl implements HymnRepository {
  final LouvorjaApi _remote;
  final AppDatabase _local;

  // Offline-first: tentar local primeiro, depois remote
  @override
  Future<List<Hymn>> getHymnsByAlbum(String albumId) async {
    final local = await _local.getHymnsByAlbum(albumId);
    if (local.isNotEmpty) return local;
    final remote = await _remote.fetchHymns(albumId);
    await _local.cacheHymns(remote);
    return remote;
  }
}
```

---

## Workflow de Desenvolvimento (TDD)

### Para cada task do PLAN.md:

```
1. LER a task no PLAN.md
2. LER a RF correspondente no SPEC.md
3. CRIAR arquivo de teste (test/)
4. RODAR teste → RED (deve falhar)
5. IMPLEMENTAR código mínimo (lib/)
6. RODAR teste → GREEN (deve passar)
7. RODAR flutter analyze → sem warnings
8. REFACTOR se necessário
9. VERIFICAR coverage 100%
10. COMMIT: `tipo(escopo): task X.Y - descrição`
```

### Comandos essenciais

```bash
# Gerar código (freezed, json_serializable, drift)
dart run build_runner build --delete-conflicting-outputs

# Analisar
flutter analyze --fatal-infos

# Testar com coverage
flutter test --coverage

# Ver coverage
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html

# Rodar em modo debug
flutter run --debug

# Build release
flutter build apk --release --split-per-abi
flutter build ipa --release
```

---

## CI/CD Pipeline

### Gates obrigatórios (PR não entra se falhar)

```yaml
# .github/workflows/ci.yml
jobs:
  analyze:
    - flutter analyze --fatal-infos
  test:
    - flutter test --coverage
    - coverage 100% (check)
    - mutation testing — zero sobreviventes (check)
  build:
    - flutter build apk --debug  # smoke test
```

### Branch Strategy

| Branch | Função |
|--------|--------|
| `main` | Produção (sempre verde) |
| `develop` | Integração contínua |
| `feature/task-X.Y` | Uma task por branch |
| `fix/issue-N` | Bug fixes |

### PR Template

```markdown
## Task: [X.Y] — [nome da task do PLAN.md]

### RF da SPEC atendida
- [ ] RF-XX: [descrição]

### Checklist
- [ ] Testes escritos antes da implementação (TDD)
- [ ] `flutter analyze` sem warnings
- [ ] Coverage 100% — zero mutantes sobreviventes
- [ ] Testes de integração nos fluxos tocados
- [ ] E2E na jornada do usuário (quando aplicável)
- [ ] Widget teste em light e dark mode
- [ ] Acessibilidade (Semantics labels)
- [ ] Offline-first (funciona sem internet)
- [ ] Code review solicitado
```

---

## Erros Comuns a Evitar

### ❌ NÃO FAÇA

1. **Hardcodar cores** — `Color(0xFF...)` inline → usar `Theme.of(context)`.
   Tokens estão em DESIGN-TOKENS.md, extraídos do design system real.
2. **Usar `BorderRadius.circular()` em cards/botões** → usar `BorderRadius.only(topLeft, bottomRight)`
   para manter a assimetria de marca (TL+BR arredondados, TR+BL retos).
2. **Lógica de negócio em widgets** — manter BLoC puro de UI
3. **Estado mutável** — sempre `freezed` para modelos imutáveis
4. **Network sem timeout** — sempre configurar timeout no Dio
5. **SQLite sem migration** — nunca `DROP TABLE` em produção
6. **Imports relativos além de `lib/`** — usar package imports para cross-module
7. **Build_runner não rodado** — após mudar modelos freezed, SEMPRE rodar
8. **Credentials no código** — usar `.env` + `flutter_dotenv` ou CI secrets
9. **Testes sem assertion** — todo teste precisa de `expect()` com resultado real
10. **Print() para debug** — usar `dart:developer` ou logger package

### ✅ SEMPRE FAÇA

1. **Theme.of(context)** para cores, estilos e dimensões
2. **BLoC para todo estado** que change durante o runtime
3. **Repository interface no domain**, implementação no data
4. **Freezed para entidades e estados**
5. **Const constructors** onde possível
6. **Key em widgets** de lista (ValueKey com id único)
7. **Dispose** controllers, streams e subscriptions
8. **Error boundaries** — ErrorWidget customizado
9. **Localization** — strings via `tr()` nunca hardcodadas
10. **Acessibilidade** — Semantics labels em todos os elementos interativos

---

## Dependência de Decisões Externas

As seguintes decisões precisam ser confirmadas com **Ezequias Fonseca**
(mantenedor do LouvorJA):

| # | Decisão | Impacto | Status |
|---|---------|---------|--------|
| 1 | Endpoints da API LouvorJA para mobile | Bloqueia Fase 2 | Pendente |
| 2 | Formato do catálogo de hinos (JSON schema) | Bloqueia Fase 2 | Pendente |
| 3 | Autorização para usar marca "LouvorJA" | Bloqueia release | Pendente |
| 4 | Conta Apple Developer ($99/ano) para iOS | Bloqueia iOS release | Pendente |
| 5 | Dados de liturgia disponíveis via API? | Bloqueia Fase 3 | Pendente |
| 6 | Dados de escala disponíveis via API? | Bloqueia Fase 5 | Pendente |
| 7 | AppId confirmação: `com.louvorja.piano.mobile` | Bloqueia setup | Pendente |
| 8 | Repo: criar `pianolouvorja/mobile` na org | Bloqueia Tudo | Pendente |

> **AGENT:** Se uma task depender de uma decisão pendente, PARE e reporte.
> Não assuma a resposta — pergunte ao usuário.

---

## Políticas de Segurança (OWASP MASVS)

### Armazenamento (MASVS-STORAGE)
- Dados sensíveis via `flutter_secure_storage` (Keystore Android / Keychain iOS)
- SQLite: sem dados pessoais (apenas hinos/liturgia/escala — dados públicos)
- Cache de imagens: `cached_network_image` com limite de tamanho

### Network (MASVS-NETWORK)
- TLS 1.2+ obrigatório (Dio rejectOnCertificateErrors)
- Certificate pinning (considerar para v1.0)
- Sem credenciais em URL params

### Platform (MASVS-PLATFORM)
- Android: backup desativado para dados sensíveis (`android:allowBackup="false"`)
- iOS: ATS (App Transport Security) estrito
- Permissões mínimas: apenas as necessárias (notificações, internet)

### Code (MASVS-CODE)
- R8/ProGuard ativo em release builds
- Sem código de debug em release (`kDebugMode` guards)
- Dependências com hash verificado (`pubspec.lock` versionado)

---

## Recursos para Agentes

### Documentação de referência
- [SPEC.md](./SPEC.md) — Requisitos funcionais e não-funcionais
- [PLAN.md](./PLAN.md) — Tasks detalhadas por fase
- [CONTEXT.md](./CONTEXT.md) — Estado técnico atual do codebase de referência

### Repos de referência (Electron/Vue)
- Desktop: `github.com/pianolouvorja/app` (v1.14.8)
- Web PWA: `github.com/pianolouvorja/web` (v1.15.5)

### Skills Hermes relevantes
- `spec-driven-development` — Metodologia SDD
- `project-excellence` — Padrão de qualidade obrigatório
- `test-driven-development` — TDD workflow
- `flutter-complete` (a criar quando implementação começar)
