# Players locais com a referência do controle remoto

A interface e o comportamento aprovados são RemoteLiturgyMirror,
RemotePlayerBar e RemoteFloatingPanel. A Liturgia local mantém seus dados,
categorias e edição, mas selecionar uma linha não executa mídia: o play abre
no APK sem projetar. Conteúdo aberto bloqueia a troca acidental de item até
fechar, com a mesma confirmação do remoto. Minimizar/expandir mantém a sessão.

A barra é compartilhada, com comandos encaminhados a um adaptador local,
sem RemoteSession nem computador obrigatório. Música, áudio, vídeo, PDF,
imagens, apresentações compatíveis, anúncios e anotações usam essa sessão.
Posição, volume, slides, modo vocal/instrumental, saída de áudio e projeção
refletem o estado real. Sites mantêm navegador local e projeção explícita.
Não haverá duplicação com o antigo player/miniplayer da Liturgia.

A projeção usa StageSession/Palco existente e apenas conexões locais realmente
disponíveis. Monitores do computador não são inventados como destinos do APK.
Preferências de executáveis externos continuam preservadas; nenhum comando do
player local é enviado ao desktop pareado.
