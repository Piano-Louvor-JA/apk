# Compatibilidade da Liturgia com o desktop

A referência de domínio é `app`, branch `feat/melhorias-app`, módulo
`src/modules/liturgy`, checkout original `ff51f8ee`. O APK adapta os contratos em
Dart e os executores ao Android. O desktop recebeu somente correções de
interoperabilidade, registradas em `ca44a15d`: chave de idioma da outbox,
relógios de edição e preservação do estado completo e das preferências de mídia.

## De/para implementado

- `types/liturgy.ts` e `liturgy-preferences.ts` → entidades e
  `LiturgyRepository`: estado `liturgy.state.pt/en/es` com semana, notas,
  horários, avulsas nomeadas e cadeados. Migração não destrutiva dos dias e das
  avulsas por data do APK; roundtrip conserva os campos extras do desktop.
- `useLiturgyStore.ts` e `liturgy-item-helpers.ts` → `LiturgyBloc` e
  `LiturgyItemRules`: vínculo e arraste de categorias/subitens, clone com novos
  IDs, conclusão dos filhos/pais, seleção, inclusão sem categoria e cadeado
  contra edição/exclusão. O primeiro acionamento registra o início real; o
  relógio da sessão independe da seleção visual. Texto e site conservam seus
  controles selecionados depois de abrir.
- `LiturgyCustomBar/CustomDialog/CloneDialog` → `LiturgyContextBar`: criar,
  renomear, excluir e clonar avulsas e dias sem sobrescrever um destino ocupado.
- `useLiturgyClock` e `liturgy-duration-enrich.ts` → `LiturgyTiming` e
  `LiturgySessionSummary`: relógio atual, início real, término planejado,
  duração total, estimativa por categoria e contagem por deadline absoluto.
- `LiturgyItemDialog.vue` → formulário mobile: mesmos grupos e tipos atuais,
  vocal/instrumental, título complementar, notas, galeria, horários HH:MM,
  duração em segundos preservada, catálogo completo e ligação com rotação.
  Tipos legados continuam legíveis.
- `rich-notes.ts`, editor e controle de texto → `RichNotes`,
  `RichNotesEditorPage` e `LiturgyTextControlPage`: HTML sanitizado, listas,
  tamanhos, alinhamentos, cores, marca-texto, cor do título, edição persistida
  e projeção. Colagem de HTML é sanitizada antes de entrar no editor.
- `useScheduledStore`, diálogo e `quarter-paste-parser.ts` → repositório,
  BLoC e tela de agendados: CRUD de rotações e entradas, escolha de conteúdo,
  agenda por data, colagem e mapeamento do trimestre, duplicação por semanas e
  importação XML Delphi. O placeholder resolve o conteúdo da sua rotação no
  dia local do culto; `categoryId` litúrgico permanece separado da rotação.
- `provai-e-vede-*` → catálogo fechado das mesmas oito fontes auditadas de
  2026 (PT/ES), importação e repositório: listar, baixar, agendar próximos ou
  episódio individual e repetir sem duplicar entradas/downloads.
- `link-info.ts` → `LiturgyLinkRepository`: metadados e duração com cache;
  preenchimento automático conserva o que o operador editou manualmente.
- Executores → catálogo persistente e player existente para música/Bíblia;
  prévia e controles de áudio/vídeo; galeria; páginas PDF pelo renderizador
  Android; texto e sites com controles de projeção. Vídeos online possuem cache
  atômico (YouTube, Vimeo público e URLs diretas); faixas de vídeo/áudio separadas
  são compostas com MediaMuxer no Android. Durações de outros codecs são
  consultadas no MediaMetadataRetriever.
- `liturgy-ja-import.ts` → parser `.ja` com UTF-8/Windows-1252, espaços nas
  chaves INI e enriquecimento pelo catálogo offline. Persistência de campos
  não suportados por arquivos legados evita perdas em uma nova gravação.
- Sync → outbox com coalescing por idioma, flush após edição e ao retomar o
  app, LWW com relógios independentes e pacote `.louvorja` com estado completo.
  O pacote mantém os dias legados e inclui também rotações e conteúdos
  agendados com data `yyyy-MM-dd`, compatível com o desktop.

## Adaptações de plataforma

O desktop usa executáveis e janelas do sistema operacional; o Android usa seus
players, renderizador PDF, WebView e aplicativos associados. Preferências de
executáveis do desktop são preservadas no arquivo compartilhado. A preferência
explícita de player não cai silenciosamente para o interno quando falha.

Apresentações compostas de imagens completas têm prévia de slides. Apresentações
com texto/formas são encaminhadas ao aplicativo associado, evitando projetar
apenas algumas imagens e perder conteúdo. Arquivos locais precisam existir no
dispositivo que os executa; a sincronização de estado não transfere binários.
Sites no Android podem ser projetados pela captura da própria página, inclusive
quando o servidor bloqueia iframe. A projeção usa o protocolo WS do projeto.

## Verificação

Os testes reproduzem as divergências antes das correções e verificam domínio,
JSON, migração, isolamento de idioma, cache, arquivos, outbox e LWW. Jornadas de
widget cobrem avulsas, clone, exclusão, horários, Bíblia offline, trimestre,
rotações, Provai idempotente, anotação, PDF e galeria. Há snapshots claro/escuro
e verificação das traduções PT-BR/EN/ES.

No emulador Android foram conferidos criação de avulsa, clone da semana,
abertura do editor e PDF local de duas páginas. Os dados temporários dessa
validação foram removidos; os roteiros existentes foram preservados. Transporte
de projeção é testado com receiver WebSocket real de teste, sem alegar validação
em hardware de TV. Electron nativo e emulador são executados com API local.

Resultados finais e pendências gerais de qualidade ficam no PLAN.md. O ratchet
Dart de cobertura já falhava no snapshot anterior: 78,82% medidos contra baseline
84,47%. O baseline não deve ser reduzido para aprovar esta entrega.
