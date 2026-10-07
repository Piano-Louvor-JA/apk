# Auditoria de Coverage — APK Flutter (05/10)
Medição: `flutter test --coverage` em worktree da origin/staging (e4ceba0).
**Pós-fix (branch fix/coverage-collector-crash): collector completa, lcov gerado, ratchet ativo.**

## Números reais
| Métrica | Valor | Meta |
|---|---|---|
| Lines | **55.46%** (5258/9481) | 100 |

145 arquivos. 878 testes passando, **2 falhando**.

## Achados críticos
1. **`flutter test --coverage` CRASHA na staging**: `album_detail_page.dart` tem blocos `coverage:ignore-start/end` ANINHADOS (125..315 contém 244..474) → `FormatException` no package:coverage e a coleta morre. **RESOLVIDO nesta branch** (fix/coverage-collector-crash): par interno removido; `flutter test --coverage` completa e gera `coverage/lcov.info` (55.46% lines). Enquanto não mergear, coverage do APK não existe pra ninguém.
2. **2 testes falhando na staging**: `stage_session_audio_route_test.dart` (modo local não envia ao palco / modo tv play-pause-stop). **Na dev-tudo (staging + PR #119) passam** — o fix de permissões/palco do #119 resolve. Conferir e mergear. Confirmado nesta rodada: +878 / -2, mesmos 2 testes.
3. **Zero gate → RESOLVIDO nesta branch**: job `coverage` no ci.yml roda `flutter test --coverage` + `scripts/coverage_ratchet.py` (falha se lines% < baseline; sobe o baseline se maior). Baseline inicial: 55.46%.

## Top gaps (>=30 linhas)
| Arquivo | Lines | Laudo |
|---|---|---|
| lib/presentation/hymns/stage_customization_sheet.dart | 0% (0/302) | REAL — tela inteira sem teste |
| lib/presentation/custom/custom_music_editor_page.dart | 0% (0/168) | REAL — editor v3.1 sem teste |
| lib/presentation/liturgy/liturgy_avulsa_page.dart | 0.4% (1/232) | REAL |
| lib/presentation/remote/unified_qr_scanner.dart | 0% (0/93) | REAL — relativo ao apk#95 |
| lib/presentation/custom/custom_timing_recorder_page.dart | 0% (0/135) | REAL |
| lib/core/services/dlna/slide_http_server.dart | 0% (0/55) | REAL — servidor HTTP do palco |
| lib/core/services/dlna/palco_mdns_discovery.dart | 0% (0/36) | REAL — relativo ao apk#90 (nota: contrato testado à parte) |
| lib/core/services/remote/p2p_remote_client.dart | 0% (0/44) | REAL |

Padrão claro: **telas (presentation) e serviços de rede DLNA/P2P** são os buracos; domain/data estão bem servidos.

## Plano pra 100
1. Fix imediato do ignore aninhado (card próprio, 2 linhas + CI de coverage verde pela 1ª vez).
2. Ratchet: piso 55.46% lines subindo por PR (lcov → script compara baseline).
3. Ondas: DLNA/palco (slide_http_server, mdns) → custom editor/recorder → liturgia avulsa → QR.
4. `--branch-coverage` (Flutter 3.47 suporta) na 2ª rodada pra ter métrica de branches.
5. Mutation (patrol/mocktail): decidir após coverage ≥75% — hoje não existe baseline de mutação no APK.
