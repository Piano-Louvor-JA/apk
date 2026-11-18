// coverage:ignore-file
// SearchDelegate depende de platform theme + MaterialLocalization; nao testavel em unit test.
library;

import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

/// SearchDelegate reutilizavel para buscar hinos.
/// Usado no HymnsPage (filtrar lista) e no LiturgyItemDialog (selecionar hino).
class HymnSearchDelegate extends SearchDelegate<Hymn?> {
  final Future<List<Hymn>> Function() _loadHymns;

  /// Busca própria (ex.: a da liturgia, igual ao desktop). Sem ela, [filter].
  final List<Hymn> Function(List<Hymn> all, String query)? search;
  List<Hymn>? _cache;

  HymnSearchDelegate(this._loadHymns, {this.search});

  /// Filtra hinos por numero, titulo ou trecho.
  static List<Hymn> filter(List<Hymn> all, String query) {
    if (query.isEmpty) return all;
    final q = query.toLowerCase().trim();
    return all.where((h) {
      final title = (h.title ?? '').toLowerCase();
      final number = h.number?.toString() ?? '';
      return title.contains(q) || number.contains(q);
    }).toList();
  }

  Future<List<Hymn>> _ensureLoaded() async {
    _cache ??= await _loadHymns();
    return _cache!;
  }

  @override
  String get searchFieldLabel => 'Buscar por numero, titulo...';

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);

  @override
  Widget buildResults(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Hymn>>(
      future: _ensureLoaded(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!;
        final filtered = query.trim().isEmpty || search == null
            ? filter(all, query)
            : search!(all, query);
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'Nenhum hino encontrado',
              style: theme.textTheme.bodyLarge,
            ),
          );
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final h = filtered[index];
            return ListTile(
              leading: h.number != null
                  ? CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${h.number}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
              title: Text(h.title ?? 'Hino ${h.id}'),
              subtitle: _subtitle(h) == null
                  ? null
                  : Text(_subtitle(h)!, style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => close(context, h),
            );
          },
        );
      },
    );
  }

  /// Coletânea e duração: diferencia músicas com o mesmo nome.
  static String? _subtitle(Hymn h) {
    final parts = [
      if ((h.albumNames ?? '').trim().isNotEmpty) h.albumNames!.trim(),
      if (h.durationMs != null && h.durationMs! > 0) h.formattedDuration,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        tooltip: 'common.clearSearch'.tr(),
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'common.back'.tr(),
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }
}
