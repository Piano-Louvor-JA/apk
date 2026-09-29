library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/services/global_search_service.dart';
import '../../domain/entities/hymn.dart';

/// Tela de busca global (RF-08): hinos + biblia numa unica query.
///
/// Fonte: SPEC.md RF-08 — resultados agrupados por categoria.
class GlobalSearchPage extends StatefulWidget {
  final GlobalSearchService service;
  final Future<List<Hymn>> Function() hymnsProvider;
  final Future<List<BibleVerseRef>> Function() versesProvider;
  final void Function(Hymn hymn)? onHymnSelected;
  final void Function(BibleVerseRef verse)? onVerseSelected;

  const GlobalSearchPage({
    super.key,
    required this.service,
    required this.hymnsProvider,
    required this.versesProvider,
    this.onHymnSelected,
    this.onVerseSelected,
  });

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _controller = TextEditingController();
  List<GlobalSearchResult> _results = const [];
  bool _loading = false;
  List<Hymn>? _hymns;
  List<BibleVerseRef>? _verses;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    setState(() => _loading = true);
    try {
      final hymns = await widget.hymnsProvider();
      final verses = await widget.versesProvider();
      if (mounted) {
        setState(() {
          _hymns = hymns;
          _verses = verses;
        });
        _runSearch(_controller.text);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _runSearch(String query) {
    if (_hymns == null || _verses == null || query.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    final hymnResults = widget.service.searchHymns(query, hymns: _hymns!);
    final bibleResults = widget.service.searchBible(query, verses: _verses!);
    final all = [...hymnResults, ...bibleResults]
      ..sort((a, b) => b.score.compareTo(a.score));
    setState(() => _results = all);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hymnResults = _results.where((r) => r.groupKey == 'hymns').toList();
    final bibleResults = _results.where((r) => r.groupKey == 'bible').toList();

    return Scaffold(
      appBar: AppBar(title: Text('search.title'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'search.placeholder'.tr(),
                prefixIcon: const Icon(TablerIcons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _runSearch,
              onChanged: (v) => _runSearch(v),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text('common.empty'.tr()))
                : ListView(
                    children: [
                      if (hymnResults.isNotEmpty) ...[
                        _GroupHeader(
                          icon: TablerIcons.music,
                          title: 'search.hymnsGroup'.tr(),
                        ),
                        for (final result in hymnResults)
                          _ResultTile(
                            title:
                                (result.item as Hymn).title ??
                                'Nº ${(result.item as Hymn).number ?? '-'}',
                            subtitle: result.snippet,
                            onTap: () => widget.onHymnSelected?.call(
                              result.item as Hymn,
                            ),
                          ),
                      ],
                      if (bibleResults.isNotEmpty) ...[
                        _GroupHeader(
                          icon: TablerIcons.book2,
                          title: 'search.bibleGroup'.tr(),
                        ),
                        for (final result in bibleResults)
                          _ResultTile(
                            title: (result.item as BibleVerseRef).reference,
                            subtitle: result.snippet,
                            onTap: () => widget.onVerseSelected?.call(
                              result.item as BibleVerseRef,
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _GroupHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ResultTile({required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
    );
  }
}
