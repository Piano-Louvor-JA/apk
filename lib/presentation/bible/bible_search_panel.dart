library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_smart_search.dart';
import 'package:louvorja_piano_mobile/presentation/bible/book_colors.dart';

/// Painel de sugestões da busca da Bíblia, abaixo do campo do AppBar.
/// Vazio: buscas recentes e exemplos. Digitando: livros (com os
/// capítulos para tocar), passagens prontas e busca no texto.
class BibleSearchPanel extends StatelessWidget {
  final String query;
  final List<BibleBook> books;
  final List<String> recents;
  final ValueChanged<BibleSuggestion> onPick;
  final void Function(BibleBook book, int chapter) onChapter;
  final ValueChanged<String> onRecent;
  final ValueChanged<String> onExample;
  final VoidCallback onClearRecents;

  static const examples = ['jo 3:16', 'sl 23', '1 co 13:4-7', 'is 53', 'amor'];

  const BibleSearchPanel({
    super.key,
    required this.query,
    required this.books,
    required this.recents,
    required this.onPick,
    required this.onChapter,
    required this.onRecent,
    required this.onExample,
    required this.onClearRecents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: query.trim().isEmpty ? _idle(theme) : _results(theme),
    );
  }

  Widget _idle(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s3),
      children: [
        if (recents.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: _header(theme, 'bible.search.recent'.tr())),
              TextButton(
                key: const Key('bible-search-clear-recents'),
                onPressed: onClearRecents,
                child: Text('bible.search.clearRecent'.tr()),
              ),
            ],
          ),
          Wrap(
            key: const Key('bible-search-recents'),
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in recents)
                ActionChip(
                  avatar: const Icon(TablerIcons.history, size: 16),
                  label: Text(r),
                  onPressed: () => onRecent(r),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
        _header(theme, 'bible.search.examples'.tr()),
        Wrap(
          key: const Key('bible-search-examples'),
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in examples)
              ActionChip(label: Text(e), onPressed: () => onExample(e)),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          'bible.search.tip'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _results(ThemeData theme) {
    final suggestions = BibleSmartSearch.suggest(query, books);
    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Text(
          'bible.search.noResults'.tr(),
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    // Capítulos para tocar: só para o livro em primeiro lugar.
    final firstBook = suggestions.first.kind == BibleSuggestionKind.book
        ? suggestions.first.book
        : null;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      children: [
        for (var i = 0; i < suggestions.length; i++) ...[
          _tile(theme, i, suggestions[i]),
          if (i == 0 && firstBook != null) _chapters(theme, firstBook),
        ],
      ],
    );
  }

  Widget _tile(ThemeData theme, int index, BibleSuggestion s) {
    final primary = index == 0;
    final Widget leading;
    final String subtitle;
    switch (s.kind) {
      case BibleSuggestionKind.book:
        leading = _badge(theme, s.book!);
        subtitle = 'bible.search.chapterCount'.tr(
          args: ['${s.book!.chapters}'],
        );
      case BibleSuggestionKind.reference:
        leading = _badge(theme, s.book!);
        subtitle = s.verses.isEmpty
            ? 'bible.search.wholeChapter'.tr()
            : 'bible.search.verseCount'.tr(args: ['${s.verses.length}']);
      case BibleSuggestionKind.text:
        leading = CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          child: const Icon(TablerIcons.textRecognition, size: 20),
        );
        subtitle = 'bible.search.textSubtitle'.tr();
    }
    final title = s.kind == BibleSuggestionKind.text
        ? 'bible.search.searchText'.tr(args: [s.query])
        : s.label;
    return ListTile(
      key: Key('bible-search-suggestion-$index'),
      leading: leading,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        s.kind == BibleSuggestionKind.book
            ? TablerIcons.arrowUpLeft
            : primary
            ? TablerIcons.cornerDownLeft
            : TablerIcons.chevronRight,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      tileColor: primary
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : null,
      onTap: () => onPick(s),
    );
  }

  Widget _chapters(ThemeData theme, BibleBook book) {
    return SizedBox(
      key: const Key('bible-search-chapters'),
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: 6,
        ),
        itemCount: book.chapters,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final chapter = i + 1;
          return SizedBox(
            width: 44,
            child: OutlinedButton(
              key: Key('bible-search-chapter-$chapter'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: BookColors.tone(book, theme),
                side: BorderSide(
                  color: BookColors.tone(book, theme).withValues(alpha: 0.4),
                ),
              ),
              onPressed: () => onChapter(book, chapter),
              child: Text('$chapter'),
            ),
          );
        },
      ),
    );
  }

  Widget _badge(ThemeData theme, BibleBook book) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BookColors.background(book, theme),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        book.abbreviation,
        style: theme.textTheme.labelLarge?.copyWith(
          color: BookColors.tone(book, theme),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s2),
    child: Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.primary,
        letterSpacing: 0.8,
      ),
    ),
  );
}
