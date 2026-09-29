import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_sheet.dart';

/// Bottom sheet "Salvar em coletânea": lista coletâneas da comunidade e
/// adiciona o hino oficial [officialMusicId] à escolhida (requer login).
///
/// Fluxo: sem sessão → abre CustomAuthSheet primeiro; depois lista.
Future<void> showSaveToCollectionSheet(
  BuildContext context, {
  required int officialMusicId,
  required String hymnTitle,
}) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final sessionStore = CustomSessionStore();
  final auth = CustomAuthApiImpl(
    fetch: (method, url, {body, bearerToken}) => dio.request<dynamic>(
      url,
      data: body,
      options: Options(
        method: method,
        headers: {
          if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
        },
      ),
    ),
    apiBaseUrl: _apiBase(),
    sessionStore: sessionStore,
  );

  var session = await sessionStore.read();
  if (session == null && context.mounted) {
    final ok = await CustomAuthSheet.show(context, CustomAuthController(auth));
    if (!ok) return;
    session = await sessionStore.read();
  }
  if (session == null || !context.mounted) return;

  final api = CustomCatalogApiImpl.withDio(
    dio: dio,
    apiBaseUrl: _apiBase(),
    filesBaseUrl: ApiConfig.urlFiles,
  );

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _CollectionPickerSheet(
      api: api,
      token: session!.token,
      officialMusicId: officialMusicId,
      hymnTitle: hymnTitle,
    ),
  );
}

/// A API custom vive na mesma origem da URL de database, menos o sufixo /json_db.
String _apiBase() {
  final db = ApiConfig.urlDatabase;
  return db.endsWith('/json_db')
      ? db.substring(0, db.length - '/json_db'.length)
      : db;
}

class _CollectionPickerSheet extends StatefulWidget {
  final CustomCatalogApiImpl api;
  final String token;
  final int officialMusicId;
  final String hymnTitle;

  const _CollectionPickerSheet({
    required this.api,
    required this.token,
    required this.officialMusicId,
    required this.hymnTitle,
  });

  @override
  State<_CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<_CollectionPickerSheet> {
  List<CustomCollection>? _collections;
  String? _error;
  final Set<int> _adding = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.fetchCollections();
      if (!mounted) return;
      setState(() {
        _collections = list;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar as coletâneas.');
    }
  }

  Future<void> _addTo(CustomCollection c) async {
    setState(() => _adding.add(c.id));
    try {
      await widget.api.addMusicToCollection(
        collectionId: c.id,
        officialMusicId: widget.officialMusicId,
        bearerToken: widget.token,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('"${widget.hymnTitle}" salvo em "${c.name}"')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _adding.remove(c.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falha ao salvar. Você é dono desta coletânea?'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Salvar "${widget.hymnTitle}" em...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _collections == null && _error == null
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _collections!.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma coletânea ainda.\nCrie uma na aba Coletâneas.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _collections!.length,
                      itemBuilder: (context, i) {
                        final c = _collections![i];
                        final busy = _adding.contains(c.id);
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${c.musicsCount}'),
                          ),
                          title: Text(c.name),
                          trailing: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add),
                          onTap: busy ? null : () => _addTo(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
