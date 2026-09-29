// Mini-sender de DEV do Palco (F3.3): mesmo PalcoSender do APK, rodando
// no Dart VM daqui para desenvolver o receiver no browser sem celular.
//
// Uso: dart run tool/palco_dev_sender.dart "texto | rodapé"
//      dart run tool/palco_dev_sender.dart --bg http://127.0.0.1:7080/media/slide-1.png
//      dart run tool/palco_dev_sender.dart --audio http://127.0.0.1:7080/media/test-external.mp3 --title "Hino 1" --sub "Harpa"
//      dart run tool/palco_dev_sender.dart --idle
import 'dart:async';
import 'dart:io';

import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

Future<void> main(List<String> args) async {
  final ctrl = PalcoController(
      sender: PalcoSender(httpPortFixed: 7080, wsPortFixed: 7081));
  final ok = await ctrl.connect(const PalcoTarget(name: 'dev', ip: '0.0.0.0'));
  if (!ok) {
    stderr.writeln('falhou ao subir sender (portas em uso?)');
    exit(1);
  }
  stderr.writeln('[dev-sender] HTTP :7080 · WS :7081 · base=${ctrl.httpBase}');
  stderr.writeln('[dev-sender] receiver: http://127.0.0.1:7080/receiver.html (ou da TV)');

  // aguarda 1s por receiver conectar
  await Future<void>.delayed(const Duration(seconds: 1));

  String? bg;
  String? audio;
  String? title;
  String? sub;
  final textParts = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--bg': bg = args[++i];
      case '--audio': audio = args[++i];
      case '--title': title = args[++i];
      case '--sub': sub = args[++i];
      case '--idle':
        ctrl.projectIdle();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        exit(0);
      default: textParts.add(args[i]);
    }
  }

  if (audio != null) {
    ctrl.playAudio(audio, title: title ?? '', subtitle: sub ?? '');
    stderr.writeln('[dev-sender] audio enviado (clients=${ctrl.clientCount})');
  } else {
    final text = textParts.join(' ');
    final pipe = text.split('|');
    ctrl.project(
      text: pipe.isNotEmpty ? pipe[0].trim() : '',
      footer: pipe.length > 1 ? pipe[1].trim() : '',
      background: bg,
    );
    stderr.writeln('[dev-sender] projection enviada (clients=${ctrl.clientCount})');
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));
  exit(0);
}
