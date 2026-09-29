<!--
  PR Template — pianolouvorja/mobile (Flutter)
  Base: SEMPRE `staging` (org: feature → staging → main).
  Uma PR única por task completa (F0..F5) — NÃO uma PR por fase.
  Commits por fase dentro da branch feat/...
-->

## 📋 Descrição
<!-- O que muda e por quê. Link para task do PLAN.md + RF da SPEC.md. -->

## ✅ Checklist de Qualidade (obrigatório)
- [ ] `flutter analyze --fatal-warnings --no-fatal-infos` passa
- [ ] `flutter test` passa (coverage >= 90%)
- [ ] `flutter build apk --debug` passa (smoke)
- [ ] **Evidência de Regressão** preenchida abaixo

## 🔁 Evidência de Regressão (obrigatório — anti-regressão)
| Métrica | Baseline (staging) | Pós-mudança (esta PR) |
|---------|-------------------|----------------------|
| Testes passed | | |
| Testes failed | | |
| Testes skipped | | |
| Analyze | OK / FAIL | OK / FAIL |

**Como obter:**
```bash
# 1. Em staging (baseline)
git checkout staging && git pull
flutter pub get
dart run scripts/test-regression.dart --baseline

# 2. Na branch da PR (comparação)
git checkout feat/sua-branch
flutter pub get
dart run scripts/test-regression.dart --compare
```
Cole os números acima. Se houver regressão → **PR não passa no CI** (gate `regression-gate`).

## 🎯 Consumidores impactados (paridade api↔app↔web↔mobile)
- [ ] Nenhum (mudança isolada)
- [ ] `pianolouvorja/app` (desktop Electron) — endpoints: ____
- [ ] `pianolouvorja/web` (Vue 3) — endpoints: ____
- [ ] `pianolouvorja/api` (Hono) — endpoints: ____
- [ ] Outro: ____

## 🧪 Como testar localmente
```bash
# passos para reproduzir/validar
```
