/// MyEditsPage — Minhas Edições do autor, READ-ONLY (portação APK, padrão F0:
/// APK consome; escrita fica no desktop/web). RF-05: status + motivo público.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/edits_api_impl.dart';
import 'package:louvorja_piano_mobile/data/models/applied_edit_model.dart';

class MyEditsPage extends StatefulWidget {
  final EditsApiImpl api;
  final Dio? dio;

  const MyEditsPage({super.key, required this.api, this.dio});

  @override
  State<MyEditsPage> createState() => _MyEditsPageState();
}

class _MyEditsPageState extends State<MyEditsPage> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    final edits = await widget.api.fetchMine();
    if (mounted) setState(() => _edits = edits);
  }

  List<MyEditSummary> _edits = const [];

  Color _statusColor(String status) => switch (status) {
    'approved' => Theme.of(context).colorScheme.primary,
    'rejected' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  String _statusLabel(String status) => switch (status) {
    'approved' => 'myEdits.statusApproved'.tr(),
    'rejected' => 'myEdits.statusRejected'.tr(),
    _ => 'myEdits.statusPublished'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('myEdits.title'.tr())),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('myEdits.loadError'.tr()),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _future = _load();
                      });
                    },
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            );
          }
          if (_edits.isEmpty) {
            return Center(child: Text('myEdits.empty'.tr()));
          }
          return ListView.builder(
            itemCount: _edits.length,
            itemBuilder: (context, index) {
              final edit = _edits[index];
              return ListTile(
                key: ValueKey(edit.id),
                leading: Chip(
                  label: Text(_statusLabel(edit.status)),
                  backgroundColor: _statusColor(edit.status).withAlpha(40),
                ),
                title: Text(
                  'myEdits.musicLabel'.tr(namedArgs: {'id': '${edit.musicId}'}),
                ),
                subtitle: edit.reason != null ? Text(edit.reason!) : null,
                // READ-ONLY: sem trailing actions — editar/publicar é desktop/web
              );
            },
          );
        },
      ),
    );
  }
}
