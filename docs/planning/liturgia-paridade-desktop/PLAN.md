# Plano executado

- [x] 1. Salvar o trabalho anterior antes de implementar (`9b79589`).
- [x] 2. Conferir tipos, helpers, store, formulário e execução no desktop.
- [x] 3. Reproduzir perdas e divergências com testes vermelhos.
- [x] 4. Adaptar os contratos de item/categoria e os formulários do APK.
- [x] 5. Rodar regressão, análise, suíte completa/cobertura e build Android.
- [x] 6. Abrir Electron nativo e emulador usando API local.
- [x] 7. Unificar persistência por idioma, migração, avulsas e horários.
- [x] 8. Sincronizar estado completo, por idioma e com LWW/outbox.
- [x] 9. Integrar avulsas nomeadas e clonagem entre roteiros.
- [x] 10. Disponibilizar rotações, agenda, trimestre e resolução por data.
- [x] 11. Disponibilizar editor rico, cor do título e projeção de texto.
- [x] 12. Conferir importação, formulários, conteúdo e execução de mídia.
- [x] 13. Conferir testes, snapshots, builds e aplicativos abertos.

## Decisões de implementação

A fonte de domínio permanece o desktop. A relação dos contratos e os adaptadores
Android estão na SPEC.md. Não foi alterada a API nem feita publicação/push.
As correções de interoperabilidade no desktop estão em `ca44a15d`.

A avulsa usa a mesma timeline, BLoC e regras da semana. A migração conserva as
chaves antigas. O começo de uma sessão limpa somente a conclusão, sem renovar o
relógio de edição do roteiro. Seleção e relógio da sessão são transitórios.

A entidade de avulsa usa Freezed. O arquivo gerado específico é versionado para
que os jobs existentes de analyze/test/build funcionem em um checkout limpo,
sem exigir uma alteração adicional nos workflows. Regenerar após editar a entidade:
`flutter pub run build_runner build --build-filter=lib/domain/entities/custom_liturgy.freezed.dart`.

A execução usa os players e serviços existentes; durações MP4 são lidas em Dart,
e outros codecs usam metadados nativos Android. O download de vídeos permanece
atômico e reutilizável offline. Não se projeta um PPTX incompleto como se fossem
slides completos: apresentações complexas seguem para o aplicativo associado.

## Verificação e pendências gerais

O teste completo, a análise e o build foram executados localmente. A criação,
clonagem e remoção de avulsa, a abertura do editor e a navegação de PDF de duas
páginas foram conferidas no emulador. O conteúdo temporário de validação foi
removido sem apagar os roteiros anteriores. Projeção WS é exercitada contra um
receiver de teste, sem alegar validação em hardware de TV.

O desktop foi validado com Node 22. Sua suíte geral tem 19 falhas anteriores:
18 reproduzidas no checkout original isolado, mais uma falha da URL de arquivos
reproduzida nesse mesmo código com a configuração local equivalente. As
alterações da Liturgia/sync passam nos testes específicos; o build passa.
Não declarar a suíte geral do desktop inteiramente verde.

O ratchet Dart usa baseline de 84,47%, já incompatível com o snapshot original
(78,82% medidos em cópia isolada). O baseline foi preservado. O gate Python usa
55,46% quando não existe baseline local. Não reduzir o baseline nem usar o piso
de staging como substituto para os gates de push/main.

## Última execução

- APK: **1.788 testes aprovados e 2 ignorados**, suíte completa com cobertura.
- Análise: nenhum erro ou warning bloqueante; 227 infos não bloqueantes.
- Build Android debug: aprovado e instalado preservando os dados do emulador.
- Cobertura: **78,78% (14.429/18.315 linhas)**. Gate Python aprovado com o
  baseline padrão de 55,46%; o arquivo de baseline gerado nessa verificação foi
  removido. Ratchet Dart reprovado contra 84,47%, problema já presente no
  snapshot de entrada (78,82%). Nenhum baseline foi alterado para aprovar o gate.
- Desktop: **10.738 testes aprovados, 1 ignorado e 19 falhas anteriores**,
  conforme a reprodução descrita acima. Build aprovado.
- Electron nativo e APK no emulador ficam abertos na Liturgia com API local.
