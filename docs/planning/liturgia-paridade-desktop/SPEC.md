# Compatibilidade da Liturgia com o desktop

A referência é o checkout `app`, branch `feat/melhorias-app`, commit `ff51f8ee`, módulo
`src/modules/liturgy`. As regras são adaptadas em Dart; o desktop não é alterado.

## Contratos tratados

- `types/liturgy.ts`: preservar os campos de item no roundtrip de armazenamento,
  inclusive título complementar, HTML/cor da anotação, rotação agendada e
  preferências de player/apresentação. Preferências específicas de desktop são
  preservadas para interoperabilidade; não indicam suporte ao programa no Android.
- `liturgy-item-helpers.ts`: adicionar/mover subitem para o fim do bloco da sua
  categoria; mover categoria com filhos; clonar com novos IDs, remapeando pais e
  limpando conclusão sem alterar a origem.
- `useLiturgyStore.ts`: concluir categoria conclui seus filhos; concluir/desfazer
  filho recalcula a categoria.
- `LITURGY_TYPE_GROUPS`: formulário oferece áudio nos arquivos internos e os
  grupos atuais de momentos; tipos legados continuam legíveis.
- `TYPES_WITHOUT_DURATION`: categoria, anotação, imagens, PDF, apresentação e
  site não entram na duração planejada nem oferecem ajuste de duração.
- Formulário: horários de categoria em HH:MM, término opcional; título
  complementar separado do subtítulo do catálogo; edição conserva conclusão,
  preferências, galeria e precisão em segundos.
- Execução: áudio local é acionável; música respeita vocal/instrumental.
- Timeline: horários da categoria e notas aparecem junto dos itens; cada bloco
  usa seu próprio índice no arraste.

## Verificação

Regressões de domínio, persistência save/reload e formulário são exercitadas em
`desktop_parity_test.dart`, `liturgy_item_dialog_title_test.dart` e
`liturgy_music_url_test.dart`. Testes escritos antes de cada correção.
Há snapshots de layout em temas claro/escuro e teste de rótulo de áudio nos
três idiomas.

A cobertura do commit anterior (`9b79589`) foi medida em uma cópia isolada:
78,82%, já abaixo do ratchet Dart configurado em 84,47%. A execução final
completa após as correções mediu 78,88% (12.419/15.745 linhas). O baseline foi
preservado. A suíte completa passou com 1.709 testes e 2 ignorados; os 6 testes
finais de formulário e snapshots claro/escuro também passaram. A análise não
apresentou erros nem warnings bloqueantes (118 infos existentes no projeto).
O APK debug foi gerado e instalado preservando os dados do emulador.

## Fronteiras ainda existentes

O APK já tinha avulsas por data; o desktop tem avulsas nomeadas. A gestão de
rotações agendadas e o editor rico de anotações também continuam distintos.
Preservar seus campos evita perda de dados, mas não equivale a disponibilizar
esses editores e todos os executores de desktop no Android. A sincronização
semanal do APK ainda usa o formato legado `days/items/notes`, não uma migração
integral para `LiturgyPersistedState` do desktop.
