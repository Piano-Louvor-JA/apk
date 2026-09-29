// coverage:ignore-file
// Dialog de criar/editar item da liturgia
// ignore_for_file: deprecated_member_use
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy/media_duration_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/scheduled_datetime_card.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/hymn_search_delegate.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';

/// Converte camelCase enum para snake_case i18n key.
String _typeToKey(dynamic type) {
  final name = type.toString().split('.').last;
  return name.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );
}

/// Grupos de tipos alinhados com o Electron LITURGY_TYPE_GROUPS.
const _typeGroups = <_TypeGroup>[
  _TypeGroup(
    labelKey: 'liturgy.dialog.groups.default',
    types: [
      LiturgyItemType.music,
      LiturgyItemType.annotation,
      LiturgyItemType.notice,
      LiturgyItemType.scheduled,
      LiturgyItemType.prayer,
      LiturgyItemType.verse,
    ],
  ),
  _TypeGroup(
    labelKey: 'liturgy.dialog.groups.internal',
    types: [
      LiturgyItemType.video,
      LiturgyItemType.images,
      LiturgyItemType.pdf,
      LiturgyItemType.presentation,
      LiturgyItemType.otherFiles,
    ],
  ),
  _TypeGroup(
    labelKey: 'liturgy.dialog.groups.external',
    types: [LiturgyItemType.onlineVideo, LiturgyItemType.site],
  ),
];

class _TypeGroup {
  final String labelKey;
  final List<LiturgyItemType> types;
  const _TypeGroup({required this.labelKey, required this.types});
}

const _urlTypes = {LiturgyItemType.onlineVideo, LiturgyItemType.site};
const _fileTypes = {
  LiturgyItemType.video,
  LiturgyItemType.images,
  LiturgyItemType.pdf,
  LiturgyItemType.presentation,
  LiturgyItemType.otherFiles,
};

/// Builder helper para um chip de tipo.
Widget _buildTypeChip(
  BuildContext ctx,
  LiturgyItemType t,
  ValueNotifier<LiturgyItemType?> type,
  StateSetter setModalState,
  ValueNotifier<int?> selectedMusicId,
  ValueNotifier<String> selectedMusicLabel,
) {
  final meta = LiturgyTypeRegistry.metaFor(t);
  final selected = type.value == t;
  return GestureDetector(
    onTap: () => setModalState(() {
      type.value = t;
      if (t != LiturgyItemType.music) {
        selectedMusicId.value = null;
        selectedMusicLabel.value = '';
      }
    }),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? meta.color.withValues(alpha: 0.2)
            : Theme.of(ctx).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: selected
            ? Border.all(color: meta.color, width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: meta.color),
          const SizedBox(width: 4),
          Text(
            'liturgy.types.${_typeToKey(t)}'.tr(),
            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

void showLiturgyItemDialog(
  BuildContext context, {
  LiturgyItem? existing,
  String? parentCategoryId,
  bool isCategory = false,
  void Function(LiturgyItem item)? onSubmit,
}) {
  final isEditing = existing != null;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
  final urlCtrl = TextEditingController(text: existing?.url ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  final filePathCtrl = TextEditingController(text: existing?.filePath ?? '');
  final scheduledAt = ValueNotifier<DateTime?>(
    existing?.scheduledAt == null
        ? null
        : DateTime.tryParse(existing!.scheduledAt!),
  );
  // null = nenhum tipo selecionado (usuario precisa escolher)
  final type = ValueNotifier<LiturgyItemType?>(existing?.type);
  final durationMinutes = ValueNotifier<int>(
    existing != null ? existing.durationMs ~/ 60000 : 0,
  );
  final selectedMusicId = ValueNotifier<int?>(existing?.musicId);
  final selectedMusicLabel = ValueNotifier<String>(existing?.name ?? '');

  if (isCategory || (existing?.type == LiturgyItemType.category)) {
    type.value = LiturgyItemType.category;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Header --
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Icon(
                        isEditing ? TablerIcons.pencil : TablerIcons.plus,
                        size: 18,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'liturgy.actions.edit'.tr()
                            : parentCategoryId != null
                            ? 'liturgy.actions.addSubItem'.tr()
                            : 'liturgy.addItem'.tr(),
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'common.close'.tr(),
                      icon: const Icon(TablerIcons.x, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),

                // -- Seletor de tipo em grupos --
                // Sempre mostra a menos que seja categoria forçada (isCategory)
                if (!isCategory) ...[
                  Text(
                    'liturgy.dialog.itemType'.tr(),
                    style: Theme.of(ctx).textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.s2),

                  // Se nao tem parentCategoryId, mostra Categoria como primeira opcao
                  if (parentCategoryId == null) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildTypeChip(
                          ctx,
                          LiturgyItemType.category,
                          type,
                          setModalState,
                          selectedMusicId,
                          selectedMusicLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s2),
                  ],

                  // Grupos de chips
                  for (final group in _typeGroups) ...[
                    if (group.types.any(
                      (t) =>
                          type.value == t ||
                          LiturgyTypeRegistry.allTypes.contains(t),
                    )) ...[
                      Text(
                        group.labelKey.tr(),
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: group.types.map((t) {
                          final meta = LiturgyTypeRegistry.metaFor(t);
                          final selected = type.value == t;
                          return GestureDetector(
                            onTap: () => setModalState(() {
                              type.value = t;
                              if (t != LiturgyItemType.music) {
                                selectedMusicId.value = null;
                                selectedMusicLabel.value = '';
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? meta.color.withValues(alpha: 0.2)
                                    : Theme.of(
                                        ctx,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                border: selected
                                    ? Border.all(color: meta.color, width: 1.5)
                                    : Border.all(
                                        color: Colors.transparent,
                                        width: 1.5,
                                      ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(meta.icon, size: 14, color: meta.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    'liturgy.types.${_typeToKey(t)}'.tr(),
                                    style: Theme.of(ctx).textTheme.labelSmall
                                        ?.copyWith(
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                    ],
                  ],
                ],

                // -- Campos dinamicos (so aparece apos escolher tipo) --
                if (type.value != null &&
                    type.value != LiturgyItemType.category) ...[
                  // Musica: buscar hino
                  if (type.value == LiturgyItemType.music) ...[
                    _MusicSelectorCard(
                      musicId: selectedMusicId,
                      musicLabel: selectedMusicLabel,
                      onSearch: () async {
                        final result = await showSearch(
                          context: context,
                          delegate: HymnSearchDelegate(() async {
                            final api = LouvorjaApiImpl(
                              baseUrls: ApiConfig.databaseUrls(),
                              filesUrls: ApiConfig.filesUrls(),
                              apiToken: const String.fromEnvironment(
                                'API_TOKEN',
                                defaultValue: '',
                              ),
                            );
                            return await api.fetchHymnal();
                          }),
                        );
                        if (result != null) {
                          setModalState(() {
                            selectedMusicId.value = result.id;
                            selectedMusicLabel.value =
                                result.title ?? 'Hino ${result.id}';
                            if (nameCtrl.text.isEmpty) {
                              nameCtrl.text = result.title ?? '';
                            }
                            if (result.durationMs != null &&
                                result.durationMs! > 0) {
                              durationMinutes.value =
                                  result.durationMs! ~/ 60000;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s3),
                  ],

                  // Agendado: data/hora
                  if (type.value == LiturgyItemType.scheduled) ...[
                    ScheduledDateTimeCard(
                      value: scheduledAt,
                      onChanged: () => setModalState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                  ],

                  // URL: site / online_video
                  if (_urlTypes.contains(type.value)) ...[
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: 'liturgy.fields.url'.tr(),
                        hintText: 'https://...',
                        prefixIcon: const Icon(TablerIcons.link, size: 18),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                  ],

                  // Arquivo: video/images/pdf/ppt/other
                  if (_fileTypes.contains(type.value)) ...[
                    _FileSelectorCard(
                      filePath: filePathCtrl,
                      onPick: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: type.value == LiturgyItemType.images
                              ? FileType.image
                              : type.value == LiturgyItemType.video
                              ? FileType.video
                              : type.value == LiturgyItemType.pdf
                              ? FileType.custom
                              : FileType.any,
                          allowMultiple: type.value == LiturgyItemType.images,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final path = result.files.first.path;
                          // Duração automática de vídeo/áudio local (MP4).
                          var probed = 0;
                          if (path != null) {
                            probed = await MediaDurationReader.readMs(path);
                          }
                          setModalState(() {
                            filePathCtrl.text = path ?? '';
                            if (nameCtrl.text.isEmpty) {
                              nameCtrl.text = result.files.first.name;
                            }
                            if (probed > 0) {
                              durationMinutes.value = probed ~/ 60000;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s3),
                  ],

                  // Duracao (stepper)
                  Row(
                    children: [
                      Text(
                        'liturgy.dialog.duration'.tr(),
                        style: Theme.of(ctx).textTheme.labelSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'common.decrease'.tr(),
                        icon: const Icon(TablerIcons.minus, size: 18),
                        onPressed: durationMinutes.value > 0
                            ? () => setModalState(() => durationMinutes.value--)
                            : null,
                      ),
                      Text(
                        '${durationMinutes.value} ${'liturgy.durationMin'.tr()}',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                      IconButton(
                        tooltip: 'common.increase'.tr(),
                        icon: const Icon(TablerIcons.plus, size: 18),
                        onPressed: durationMinutes.value < 99
                            ? () => setModalState(() => durationMinutes.value++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                ],

                // -- Campos comuns (nome, subtitulo, notas) --
                // So aparecem apos escolher tipo OU se for categoria
                if (type.value != null) ...[
                  TextField(
                    controller: nameCtrl,
                    autofocus: !isEditing,
                    decoration: InputDecoration(
                      labelText: type.value == LiturgyItemType.category
                          ? 'liturgy.dialog.categoryMomentName'.tr()
                          : 'liturgy.dialog.momentName'.tr(),
                      hintText: 'liturgy.categoryPlaceholder'.tr(),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  TextField(
                    controller: subtitleCtrl,
                    decoration: InputDecoration(
                      labelText: 'liturgy.dialog.complementaryTitle'.tr(),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'liturgy.notes'.tr(),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],

                // -- Botoes --
                if (type.value != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('liturgy.actions.cancel'.tr()),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      FilledButton.icon(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty &&
                              selectedMusicId.value == null &&
                              filePathCtrl.text.isEmpty &&
                              urlCtrl.text.isEmpty) {
                            return;
                          }
                          final item = LiturgyItem(
                            id:
                                existing?.id ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            type: type.value!,
                            name: name.isNotEmpty
                                ? name
                                : selectedMusicLabel.value,
                            subtitle: subtitleCtrl.text.trim(),
                            durationMs: durationMinutes.value * 60000,
                            categoryId:
                                parentCategoryId ?? existing?.categoryId,
                            accentColor: existing?.accentColor ?? '',
                            musicId: selectedMusicId.value,
                            url: urlCtrl.text.trim().isNotEmpty
                                ? urlCtrl.text.trim()
                                : null,
                            filePath: filePathCtrl.text.trim().isNotEmpty
                                ? filePathCtrl.text.trim()
                                : null,
                            notes: notesCtrl.text.trim().isNotEmpty
                                ? notesCtrl.text.trim()
                                : null,
                            scheduledAt:
                                type.value == LiturgyItemType.scheduled &&
                                    scheduledAt.value != null
                                ? scheduledAt.value!.toIso8601String()
                                : null,
                          );
                          if (onSubmit != null) {
                            onSubmit(item);
                          } else if (isEditing) {
                            context.read<LiturgyBloc>().add(
                              LiturgyUpdateItem(item),
                            );
                          } else {
                            context.read<LiturgyBloc>().add(
                              LiturgyAddItem(item),
                            );
                          }
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(TablerIcons.check, size: 18),
                        label: Text(
                          isEditing
                              ? 'liturgy.actions.save'.tr()
                              : 'liturgy.actions.addToService'.tr(),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.s2),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// --- Music selector card ---

class _MusicSelectorCard extends StatelessWidget {
  final ValueNotifier<int?> musicId;
  final ValueNotifier<String> musicLabel;
  final VoidCallback onSearch;

  const _MusicSelectorCard({
    required this.musicId,
    required this.musicLabel,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<int?>(
      valueListenable: musicId,
      builder: (context, id, _) {
        return ValueListenableBuilder<String>(
          valueListenable: musicLabel,
          builder: (context, label, _) {
            return Card(
              color: theme.colorScheme.surfaceContainerHigh,
              child: InkWell(
                onTap: onSearch,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        id != null
                            ? TablerIcons.musicCheck
                            : TablerIcons.musicSearch,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              id != null
                                  ? 'liturgy.fields.selectMusic'.tr()
                                  : 'liturgy.fields.searchMusic'.tr(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (label.isNotEmpty)
                              Text(
                                label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        TablerIcons.chevronRight,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- File selector card ---

class _FileSelectorCard extends StatelessWidget {
  final TextEditingController filePath;
  final VoidCallback onPick;

  const _FileSelectorCard({required this.filePath, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = filePath.text.trim().isNotEmpty;
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onPick,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                hasFile ? TablerIcons.fileCheck : TablerIcons.fileUpload,
                size: 22,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFile
                          ? 'liturgy.fields.changeFileButton'.tr()
                          : 'liturgy.fields.selectFileButton'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasFile)
                      Text(
                        filePath.text.split('/').last,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
