library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Destino temporário para deep-links cuja implementação de dados chega na Fase 2.
/// Mantém URLs estáveis já na Fundação sem fingir que o conteúdo existe.
class DetailPlaceholderPage extends StatelessWidget {
  final String title;
  final String identifier;

  const DetailPlaceholderPage({
    super.key,
    required this.title,
    required this.identifier,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('${'common.id'.tr()}: $identifier')),
    );
  }
}
