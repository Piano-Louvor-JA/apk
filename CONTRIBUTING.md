# Contribuindo — apk (app Flutter)

## Fluxo de branch (padrão da org)

1. Branch de feature a partir de `staging`
2. PR com base **staging** (NUNCA direto pra main)
3. CI precisa estar verde: lint → test → build-android → build-ios → regression-gate → quality-gate
4. Review humano antes do merge
5. `staging → main` é release (via PR, depois de validar em homologação)

## Desenvolvimento

```bash
flutter pub get
flutter test          # suíte completa (880+ testes)
flutter analyze       # lint
dart run scripts/test-regression.dart --compare  # gate de regressão (precisa baseline)
```

## Regras

- Testes com vídeo: música SACRA IASD (nunca mundana)
- Offline-first: downloads e progresso JAMAIS podem se perder com reload, segundo plano ou atualização
- API 100% via `--dart-define` (ver ci.yml para as flags obrigatórias)
- Commits seguem conventional commits (`feat:`, `fix:`, `chore:`...)
