/// Página placeholder genérica para tabs ainda não implementadas.
library;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'empty_state.dart';
import 'gradient_background.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const PlaceholderPage({
    super.key,
    required this.title,
    this.message = 'Esta seção será implementada nas próximas fases.',
    this.icon = TablerIcons.moodEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: EmptyState(icon: icon, title: title, message: message),
            ),
          ],
        ),
      ),
    );
  }
}
