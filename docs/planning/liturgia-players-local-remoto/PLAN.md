# Implementação

1. Testes de selecionar/play/fechar, estado local e comandos compartilhados.
2. Adaptador local de mídia e sessão BLoC, com descarte e troca seguros.
3. Reutilizar RemotePlayerBar e painel flutuante com estado/comandos injetados.
4. Integrar escolha pendente e bloqueio na timeline local.
5. Validar música, áudio/vídeo, documentos, imagens, texto e projeção explícita.
6. Rodar testes, snapshots, análise e build; instalar e conferir no emulador.

## Concluído

- Barra e painel flutuante compartilhados com o remoto; comandos, presença, quadros e streams locais injetados.
- Música com fundos e letras sincronizadas; vídeo/áudio nativos; PDF, imagens, anúncios textuais e anotações com edição.
- Seleção separada do play, projeção explícita, confirmação ao fechar e bloqueio da timeline durante execução.
- Telas reais do Palco, roteamento de áudio e projeção independente sobrepor/compartilhar pelo protocolo existente do receiver.
- Mantidos os executores de Bíblia, sites, apresentações e aplicativos externos; agora também aguardam play.
- 1.813 testes aprovados, 2 ignorados; snapshots claro/escuro e integração WebSocket aprovados.
- Análise sem erros/warnings bloqueantes; build Android debug aprovado e instalado sem apagar os dados.
- Conferência no emulador: seleção sem execução e música Tu És Digno com fundo.

### Cobertura

Cobertura de linhas: 78,64%. O ratchet Python com piso padrão foi aprovado. O ratchet Dart continua bloqueado pelo baseline histórico de 84,47%; o snapshot anterior ao trabalho já tinha 78,82%. Não alteramos nem reduzimos o baseline versionado.
