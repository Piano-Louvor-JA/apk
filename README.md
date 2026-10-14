# Piano LouvorJA

![CI](https://img.shields.io/github/actions/workflow/status/Piano-Louvor-JA/apk/ci.yml?branch=main&label=CI)
![Security](https://img.shields.io/github/actions/workflow/status/Piano-Louvor-JA/apk/security.yml?branch=main&label=security)
![Release](https://img.shields.io/github/v/release/Piano-Louvor-JA/apk)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-lightgrey)

App Flutter para gerenciamento de cultos adventistas — companheiro mobile do [Piano LouvorJA Desktop](https://github.com/Piano-Louvor-JA/app).

## Funcionalidades

- **Hinos** — Catálogo completo com Hinário Adventista (Atual e 1996), coletâneas oficiais, busca por título/número, play/pause por faixa, letras expansíveis e capas
- **Bíblia** — Navegação por livro/capítulo com cores canônicas, tabs AT/NT, seleção de versão
- **Liturgia** — Cronograma de culto com cronômetro (manual ou horário programado), collapse de categorias, duração estimada e executor de itens
- **Timer** — Stopwatch e countdown com presets persistentes, alerta local e vibração ao concluir
- **Configurações** — Tema (claro/sistema/escuro), cor de acento, perfil de interação, idioma, verificação manual de atualizações e reset de fábrica
- **Auto-update** — Verificação automática via GitHub Releases + banner + instalação de APK sem Play Store
- **Offline** — Repositório de músicas offline com download sob demanda (em desenvolvimento)

## Tech Stack

- **Flutter** 3.44+ / **Dart** 3.12+
- **State**: flutter_bloc
- **Routing**: go_router
- **Networking**: Dio com retry e rate-limit
- **Audio**: audioplayers (native) / dart:html AudioElement (web)
- **i18n**: easy_localization (pt-BR, en, es)
- **Notifications**: flutter_local_notifications
- **Auto-update**: GitHub Releases API + OpenFilex

## Arquitetura

Clean Architecture com separação em camadas:

```
lib/
├── app/           # Router, tema, spacing
├── core/          # Serviços (audio, update, countdown, settings)
├── data/          # Repositórios e datasources (remote/local)
├── domain/        # Entidades e interfaces de repositórios
└── presentation/  # Páginas, widgets, blocs
```

## Desenvolvimento

```bash
flutter pub get
flutter analyze --fatal-infos
flutter test --coverage
```

### Build

```bash
# Web
flutter build web --release --dart-define=API_TOKEN=sua_chave

# Android APK
flutter build apk --release --dart-define=API_TOKEN=sua_chave
```

### Publicar atualização

1. Incrementar versão em `pubspec.yaml`
2. Build APK release
3. Criar GitHub Release com a tag `vX.Y.Z` e anexar o APK
4. Usuários recebem o banner automaticamente

## Paridade com Desktop

O APK é um app de **operação** (controle + navegação + play). Projeção, múltiplos monitores, PPTX/LibreOffice/FTP e desenho desktop pertencem ao produto LouvorJA Palco (futuro).

## Licença

Proprietário — © Pianolouvorja
