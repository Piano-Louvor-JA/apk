import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/scheduled_resolver.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/media_duration_reader.dart';
import 'package:louvorja_piano_mobile/core/utils/liturgy_format.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_catalog_repository.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

class ScheduledItemPreview extends StatefulWidget {
  const ScheduledItemPreview({
    super.key,
    required this.item,
    required this.date,
  });
  final LiturgyItem item;
  final DateTime date;
  @override
  State<ScheduledItemPreview> createState() => _ScheduledItemPreviewState();
}

class _ScheduledItemPreviewState extends State<ScheduledItemPreview> {
  Future<LiturgyItem?>? _resolved;
  String? _language;
  StreamSubscription<void>? _changes;
  Future<LiturgyItem?> _load() async {
    final language = _language ?? 'pt';
    final repo = ScheduledRepository(await SharedPreferences.getInstance());
    var item = ScheduledResolver.resolve(
      widget.item,
      widget.date,
      repo.loadCategories(),
      repo.loadItems(),
    );
    if (item?.type == LiturgyItemType.video ||
        item?.type == LiturgyItemType.audio) {
      final path = item?.filePath;
      if (path != null) {
        final duration = await MediaDurationReader.readMs(path);
        if (duration > 0) item = item!.copyWith(durationMs: duration);
      }
    }
    if (item?.type == LiturgyItemType.music && item?.musicId != null) {
      final catalog = await LiturgyCatalogRepository.open(language);
      final music = catalog.cachedMusic(item!.musicId!);
      if (music?.durationMs != null)
        item = item.copyWith(durationMs: music!.durationMs);
    }
    return item;
  }

  @override
  void initState() {
    super.initState();
    _changes = ScheduledRepository.changes.listen((_) {
      if (mounted)
        setState(() {
          _resolved = _load();
        });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = EasyLocalization.of(context)?.locale.languageCode ?? 'pt';
    if (_language != language) {
      _language = language;
      _resolved = _load();
    }
  }

  @override
  void didUpdateWidget(covariant ScheduledItemPreview old) {
    super.didUpdateWidget(old);
    if (old.item.scheduledRotationId != widget.item.scheduledRotationId ||
        old.date != widget.date ||
        old.item.name != widget.item.name)
      _resolved = _load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LiturgyItem?>(
    future: _resolved,
    builder: (context, snapshot) {
      final item = snapshot.data;
      if (item == null)
        return Text(
          'liturgy.parity.scheduledEmptyForDate'.tr(
            namedArgs: {'date': DateFormat('dd/MM').format(widget.date)},
          ),
          style: Theme.of(context).textTheme.bodySmall,
        );
      return Row(
        children: [
          Icon(LiturgyTypeRegistry.iconFor(item.type), size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              item.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (item.durationMs > 0)
            Text(
              LiturgyFormat.formatElapsed(item.durationMs),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      );
    },
  );
}
