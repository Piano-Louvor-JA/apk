library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_page.dart'
    show RemoteLiturgyMirror;
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_stop_video_button.dart';

/// Liturgia do DESKTOP, aberta pelo Controle Remoto: mesma lista do
/// computador, toque = executa lá. Separada da Liturgia nativa do apk.
class RemoteLiturgyPage extends StatefulWidget {
  const RemoteLiturgyPage({super.key});

  @override
  State<RemoteLiturgyPage> createState() => _RemoteLiturgyPageState();
}

class _RemoteLiturgyPageState extends State<RemoteLiturgyPage> {
  StreamSubscription<RemotePlayerState>? _sub;
  RemotePlayerState? _state;

  @override
  void initState() {
    super.initState();
    _state = RemoteSession.instance.lastState;
    _sub = RemoteSession.instance.states.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final hasItems =
        state != null &&
        state.liturgyItems.isNotEmpty &&
        RemoteSession.instance.isControlling;
    return Scaffold(
      appBar: AppBar(
        title: Text('remote.tabLiturgy'.tr()),
        actions: const [StageStopVideoButton()],
      ),
      body: hasItems
          ? RemoteLiturgyMirror(state: state)
          : Center(
              key: const Key('remote-liturgy-empty'),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'remote.noLiturgy'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}
