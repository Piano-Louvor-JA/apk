import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/local_custom_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collection_edit_page.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_sheet.dart';

/// Coletâneas Custom da comunidade (v1 — leitura).
///
/// Lista coletâneas públicas da API custom, permite ver o detalhe
/// (músicas) e baixar uma coletânea inteira para uso offline.
class CustomCollectionsPage extends StatefulWidget {
  /// Injeção opcional de Dio (testes). Null = Dio padrão com timeouts.
  final Dio? dio;

  /// Injeção opcional do controller de auth (testes). Null = real
  /// (secure storage + API) — só em runtime, nunca em widget test.
  final CustomAuthController? authController;

  const CustomCollectionsPage({super.key, this.dio, this.authController});

  /// Dio padrão da página. Visível p/ testes (RF-01: timeouts 8s/15s).
  @visibleForTesting
  static Dio buildDefaultDio() => Dio(
    BaseOptions(
      // Sem timeout o request fica pendurado quando o host não responde
      // (ex.: saiu do Wi-Fi de casa) — falha rápida com erro claro.
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  @override
  State<CustomCollectionsPage> createState() => _CustomCollectionsPageState();
}

class _CustomCollectionsPageState extends State<CustomCollectionsPage> {
  late final CustomCatalogApiImpl _api;
  late final CustomAuthController _auth;
  late final LocalCustomStore _localStore;
  List<CustomCollection>? _collections;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = CustomCatalogApiImpl.withDio(
      dio: widget.dio ?? CustomCollectionsPage.buildDefaultDio(),
      apiBaseUrl: _apiBase(),
      filesBaseUrl: ApiConfig.urlFiles,
    );
    _localStore = LocalCustomStore(
      null,
    ); // memória por ora; device dir quando integrar path_provider
    _auth =
        widget.authController ??
        CustomAuthController(
          CustomAuthApiImpl(
            fetch: _dioFetch,
            apiBaseUrl: _apiBase(),
            sessionStore: CustomSessionStore(),
          ),
        );
    _auth.restore().then((_) => _load());
  }

  /// Ponte Dio → assinatura CustomFetch (usada pelo auth).
  Future<dynamic> _dioFetch(
    String method,
    String url, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) {
    final dio = widget.dio ?? CustomCollectionsPage.buildDefaultDio();
    return dio.request<dynamic>(
      url,
      data: body,
      options: Options(
        method: method,
        headers: {
          if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
        },
      ),
    );
  }

  /// A API custom vive na mesma origem da URL de database, menos o sufixo /json_db.
  static String _apiBase() {
    final db = ApiConfig.urlDatabase;
    return db.endsWith('/json_db')
        ? db.substring(0, db.length - '/json_db'.length)
        : db;
  }

  Future<void> _load() async {
    try {
      final collections = await _api.fetchCollections(
        bearerToken: _auth.session?.token,
      );
      final local = _localStore
          .listLocalCollections()
          .map(
            (c) => CustomCollection(
              id: (c['id'] as num).toInt(),
              name: c['name'] as String? ?? '',
              musicsCount: _localStore
                  .listLocalMusics((c['id'] as num).toInt())
                  .length,
              isOwner: true,
              authorName: c['author'] as String?,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _collections = [...local, ...collections];
        _error = null;
      });
    } catch (e) {
      // Diagnóstico: sem este log o catch engole a exceção e fica impossível
      // distinguir timeout de DNS de conexão recusada no logcat.
      // ignore: avoid_print
      print('[custom-collections] erro ao carregar: $e');
      if (!mounted) return;
      final detalhe = e is DioException ? ' (${e.type.name})' : '';
      setState(
        () => _error =
            'Não foi possível carregar as coletâneas$detalhe.\nVerifique sua conexão e tente novamente.',
      );
    }
  }

  /// Tap no check de coletânea já baixada: confirma e remove o download
  /// (a coletânea continua visível na lista da comunidade).
  Future<void> _removeDownload(CustomCollection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remover download de "${collection.name}"?'),
        content: const Text(
          'A coletânea continua disponível na comunidade — só deixa de '
          'estar marcada como baixada neste dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.leaveCollection(collection);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download de "${collection.name}" removido.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao remover download.')),
      );
    }
  }

  Future<void> _download(CustomCollection collection) async {
    try {
      await _api.joinCollection(collection);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coletânea "${collection.name}" baixada!')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao baixar coletânea.')),
      );
    }
  }

  Future<void> _createCollection() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova coletânea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (created != true || !mounted) return;

    final name = nameController.text.trim();
    if (name.isEmpty) return;

    // SEM auth: cria local (fica só neste dispositivo, nunca vai pra API).
    if (!_auth.isAuthenticated) {
      _localStore.createLocalCollection(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coletânea "$name" criada neste dispositivo '
            '(entre na sua conta para compartilhar).',
          ),
        ),
      );
      _load();
      return;
    }

    try {
      final token = _auth.session?.token;
      await _api.createCollection(
        name: name,
        description: descController.text.trim(),
        authorName: _auth.session?.user.displayName,
        bearerToken: token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Coletânea "$name" criada!')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falha ao criar coletânea. Você está logado?'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coletâneas da Comunidade'),
        actions: [
          AnimatedBuilder(
            animation: _auth,
            builder: (context, _) {
              if (_auth.isAuthenticated) {
                return IconButton(
                  tooltip: 'Sair',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await _auth.logout();
                    if (mounted) {
                      await _load(); // recarrega sem Bearer (is_owner zera)
                    }
                  },
                );
              }
              return IconButton(
                tooltip: 'Entrar',
                icon: const Icon(Icons.login),
                onPressed: () async {
                  await CustomAuthSheet.show(context, _auth);
                  if (mounted) {
                    await _load(); // recarrega com Bearer → is_owner correto
                  }
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCollection,
        icon: const Icon(Icons.add),
        label: const Text('Nova coletânea'),
      ),
      body: _collections == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _collections!.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Nenhuma coletânea compartilhada ainda.\n\nCrie a primeira no app de desktop!',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _collections!.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final c = _collections![index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${c.musicsCount}'),
                            ),
                            title: Text(c.name),
                            subtitle: c.authorName != null
                                ? Text('por ${c.authorName}')
                                : null,
                            onTap: c.id < 0
                                ? () async {
                                    // coletânea LOCAL (sem auth): edição
                                    // offline, dados só do dispositivo.
                                    final deleted = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CustomCollectionEditPage(
                                                  api: _api,
                                                  collection: c,
                                                  localStore: _localStore,
                                                ),
                                          ),
                                        );
                                    if ((deleted ?? false) && mounted) _load();
                                  }
                                : c.isOwner && _auth.isAuthenticated
                                ? () async {
                                    final deleted = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CustomCollectionEditPage(
                                                  api: _api,
                                                  collection: c,
                                                  bearerToken:
                                                      _auth.session!.token,
                                                ),
                                          ),
                                        );
                                    if ((deleted ?? false) && mounted) _load();
                                  }
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Coletânea de outro autor — somente '
                                          'leitura. Baixe para ouvir offline.',
                                        ),
                                      ),
                                    );
                                  },
                            trailing: FutureBuilder<Set<int>>(
                              future: _api.fetchJoinedCollectionIds(),
                              builder: (context, snapshot) {
                                final joined =
                                    snapshot.data?.contains(c.id) ?? false;
                                return joined
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.download_done,
                                          color: Colors.green,
                                        ),
                                        tooltip: 'Remover download',
                                        onPressed: () => _removeDownload(c),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.download),
                                        tooltip: 'Baixar',
                                        onPressed: () => _download(c),
                                      );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
