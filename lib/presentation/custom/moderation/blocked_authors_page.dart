import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/blocked_author.dart';

/// Lista de autores bloqueados, com desbloqueio (App Store 1.2).
class BlockedAuthorsPage extends StatefulWidget {
  final CustomCatalogApiImpl api;
  final String bearerToken;

  const BlockedAuthorsPage({
    super.key,
    required this.api,
    required this.bearerToken,
  });

  @override
  State<BlockedAuthorsPage> createState() => _BlockedAuthorsPageState();
}

class _BlockedAuthorsPageState extends State<BlockedAuthorsPage> {
  List<BlockedAuthor>? _authors;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final authors = await widget.api.fetchBlockedAuthors(
        bearerToken: widget.bearerToken,
      );
      if (!mounted) return;
      setState(() {
        _authors = authors;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar. Tente novamente.');
    }
  }

  Future<void> _unblock(BlockedAuthor author) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.unblockAuthor(
        author.id,
        bearerToken: widget.bearerToken,
      );
      if (!mounted) return;
      setState(() => _authors = [...?_authors]..remove(author));
      messenger.showSnackBar(
        SnackBar(content: Text('${author.name} desbloqueado.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Falha ao desbloquear.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authors = _authors;
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários bloqueados')),
      body: _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : authors == null
          ? const Center(child: CircularProgressIndicator())
          : authors.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Você não bloqueou ninguém.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: authors.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final author = authors[index];
                return ListTile(
                  title: Text(author.name),
                  trailing: TextButton(
                    onPressed: () => _unblock(author),
                    child: const Text('Desbloquear'),
                  ),
                );
              },
            ),
    );
  }
}
