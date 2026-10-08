// SPEC 7 (apk#92) — singleton global do status offline (mesmo padrão do
// nowPlaying): qualquer widget pode assistir; o boot inicia uma única vez.
library;

import 'connectivity_service.dart';

final offlineStatus = OfflineStatusController();
