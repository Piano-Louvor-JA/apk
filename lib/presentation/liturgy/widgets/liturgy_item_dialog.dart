// coverage:ignore-file
// Dialog de criar/editar item da liturgia
// ignore_for_file: deprecated_member_use
library;

import 'dart:async';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_link_repository_impl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_item_rules.dart';
import 'package:louvorja_piano_mobile/core/utils/liturgy_format.dart';
import 'package:file_picker/file_picker.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy_music_search.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/media_duration_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/scheduled_rotation_picker.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/rich_notes_editor_page.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_verse_fields.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/rich_notes.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_catalog_repository.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/hymn_search_delegate.dart';

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
      LiturgyItemType.scheduled,
      LiturgyItemType.annotation,
    ],
  ),
  _TypeGroup(
    labelKey: 'liturgy.dialog.groups.internal',
    types: [
      LiturgyItemType.audio,
      LiturgyItemType.video,
      LiturgyItemType.images,
      LiturgyItemType.pdf,
      LiturgyItemType.presentation,
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
  LiturgyItemType.audio,
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
  Set<LiturgyItemType>? allowedTypes,
  List<LiturgyItem>? categoryOptions,
  void Function(LiturgyItem item)? onSubmit,
}) {
  final isEditing = existing != null;
  var categories = categoryOptions ?? <LiturgyItem>[];
  if (categoryOptions == null) {
    try {
      final state = context.read<LiturgyBloc>().state;
      if (state is LiturgyLoaded)
        categories = state.items
            .where((e) => e.type == LiturgyItemType.category)
            .toList();
    } catch (_) {
      /* formulário independente (agenda) */
    }
  }
  final category = ValueNotifier<String?>(
    parentCategoryId ?? existing?.categoryId,
  );
  final rotation = ValueNotifier<String?>(existing?.scheduledRotationId);
  final verseBook = ValueNotifier<int?>(existing?.verseBookId);
  final verseChapter = ValueNotifier<int?>(existing?.verseChapter);
  final verseNumbers = TextEditingController(
    text: existing?.verseNumbers ?? '',
  );
  var annotationHtml = RichNotes.sanitize(existing?.notesHtml);
  if (annotationHtml.isEmpty)
    annotationHtml = RichNotes.fromPlainText(existing?.subtitle ?? '');
  var titleColor = RichNotes.titleColor(existing?.titleColor);
  var playerId = existing?.playerId ?? 'default';
  final descriptionCtrl = TextEditingController(text: existing?.subtitle ?? '');
  Timer? linkTimer;
  var open = true;
  var loadingLink = false;
  var autoName = '', autoDescription = '';

  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final subtitleCtrl = TextEditingController(
    text: existing?.complementaryTitle ?? '',
  );
  final startTimeCtrl = TextEditingController(text: existing?.startTime ?? '');
  final endTimeCtrl = TextEditingController(text: existing?.endTime ?? '');
  final musicMode = ValueNotifier<String>(existing?.musicMode ?? 'audio');
  var paths = [...?existing?.filePaths];
  var durationMs = existing?.durationMs ?? 0;
  final urlCtrl = TextEditingController(text: existing?.url ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  final filePathCtrl = TextEditingController(text: existing?.filePath ?? '');
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

  final sheet = showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _DialogResourceOwner(
      onDispose: () {
        open = false;
        linkTimer?.cancel();
        for (final controller in [
          verseNumbers,
          nameCtrl,
          subtitleCtrl,
          startTimeCtrl,
          endTimeCtrl,
          urlCtrl,
          notesCtrl,
          filePathCtrl,
          descriptionCtrl,
        ]) {
          controller.dispose();
        }
        for (final notifier in <ChangeNotifier>[
          category,
          rotation,
          verseBook,
          verseChapter,
          musicMode,
          type,
          durationMinutes,
          selectedMusicId,
          selectedMusicLabel,
        ]) {
          notifier.dispose();
        }
      },
      child: StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
                    if (parentCategoryId == null &&
                        (allowedTypes == null ||
                            allowedTypes.contains(
                              LiturgyItemType.category,
                            ))) ...[
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

                    if (allowedTypes?.contains(LiturgyItemType.verse) == true)
                      _buildTypeChip(
                        ctx,
                        LiturgyItemType.verse,
                        type,
                        setModalState,
                        selectedMusicId,
                        selectedMusicLabel,
                      ),
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
                          children: group.types
                              .where(
                                (t) =>
                                    allowedTypes == null ||
                                    allowedTypes.contains(t),
                              )
                              .map((t) {
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
                                          : Theme.of(ctx)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                      border: selected
                                          ? Border.all(
                                              color: meta.color,
                                              width: 1.5,
                                            )
                                          : Border.all(
                                              color: Colors.transparent,
                                              width: 1.5,
                                            ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          meta.icon,
                                          size: 14,
                                          color: meta.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'liturgy.types.${_typeToKey(t)}'.tr(),
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .labelSmall
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
                              })
                              .toList(),
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
                            // Igual ao desktop: todo o catálogo (índice de
                            // músicas) e a busca da liturgia (título, número,
                            // coletânea, erro de digitação e letra).
                            delegate: HymnSearchDelegate(() async {
                              final catalog =
                                  await LiturgyCatalogRepository.open(
                                    EasyLocalization.of(
                                          context,
                                        )?.locale.languageCode ??
                                        'pt',
                                  );
                              return catalog.musicIndex();
                            }, search: LiturgyMusicSearch.search),
                          );
                          if (result != null) {
                            setModalState(() {
                              selectedMusicId.value = result.id;
                              selectedMusicLabel.value =
                                  result.title ?? 'Hino ${result.id}';
                              nameCtrl.text = result.title ?? '';
                              descriptionCtrl.text = result.albumNames ?? '';
                              if (result.durationMs != null &&
                                  result.durationMs! > 0) {
                                durationMs = result.durationMs!;
                                durationMinutes.value = durationMs ~/ 60000;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.s3),
                    ],

                    if (type.value == LiturgyItemType.music)
                      DropdownButtonFormField<String>(
                        initialValue: musicMode.value,
                        decoration: InputDecoration(
                          labelText: 'liturgy.fields.musicMode'.tr(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'audio',
                            child: Text('liturgy.fields.vocal'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'instrumental',
                            child: Text('liturgy.fields.instrumental'.tr()),
                          ),
                        ],
                        onChanged: (value) => setModalState(
                          () => musicMode.value = value ?? 'audio',
                        ),
                      ),

                    // Agendado: data/hora
                    if (type.value == LiturgyItemType.scheduled) ...[
                      ScheduledRotationPicker(
                        value: rotation.value,
                        onChanged: (id) =>
                            setModalState(() => rotation.value = id),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                    ],

                    if (type.value == LiturgyItemType.verse)
                      LiturgyVerseFields(
                        book: verseBook,
                        chapter: verseChapter,
                        numbers: verseNumbers,
                      ),
                    if (type.value == LiturgyItemType.annotation) ...[
                      OutlinedButton.icon(
                        key: const Key('liturgy-rich-editor'),
                        onPressed: () async {
                          final html = await Navigator.of(ctx).push<String>(
                            MaterialPageRoute(
                              builder: (_) => RichNotesEditorPage(
                                html: annotationHtml.isEmpty
                                    ? RichNotes.fromPlainText(notesCtrl.text)
                                    : annotationHtml,
                              ),
                            ),
                          );
                          if (html != null && ctx.mounted)
                            setModalState(() => annotationHtml = html);
                        },
                        icon: const Icon(TablerIcons.textSize),
                        label: Text('liturgy.parity.formattedText'.tr()),
                      ),
                      if (annotationHtml.isNotEmpty)
                        Text(
                          RichNotes.plainText(annotationHtml),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final color = await showModalBottomSheet<String>(
                            context: ctx,
                            builder: (picker) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(picker, ''),
                                      child: Text(
                                        'liturgy.parity.defaultColor'.tr(),
                                      ),
                                    ),
                                    for (final hex in RichNotes.colors)
                                      Semantics(
                                        label: hex,
                                        button: true,
                                        child: InkWell(
                                          onTap: () =>
                                              Navigator.pop(picker, hex),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            color: Color(
                                              int.parse(
                                                'ff${hex.substring(1)}',
                                                radix: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (color != null && ctx.mounted)
                            setModalState(() => titleColor = color);
                        },
                        icon: Icon(
                          TablerIcons.palette,
                          color: titleColor.isEmpty
                              ? null
                              : Color(
                                  int.parse(
                                    'ff${titleColor.substring(1)}',
                                    radix: 16,
                                  ),
                                ),
                        ),
                        label: Text('liturgy.parity.titleColor'.tr()),
                      ),
                    ],
                    if (type.value != LiturgyItemType.category &&
                        parentCategoryId == null)
                      DropdownButtonFormField<String>(
                        key: const Key('liturgy-item-category'),
                        initialValue:
                            categories.any((e) => e.id == category.value)
                            ? category.value
                            : '',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'liturgy.parity.category'.tr(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text('liturgy.parity.noCategory'.tr()),
                          ),
                          for (final cat in categories)
                            DropdownMenuItem(
                              value: cat.id,
                              child: Text(cat.name),
                            ),
                        ],
                        onChanged: (id) =>
                            setModalState(() => category.value = id),
                      ),

                    if ({
                      LiturgyItemType.audio,
                      LiturgyItemType.video,
                      LiturgyItemType.onlineVideo,
                    }.contains(type.value))
                      DropdownButtonFormField<String>(
                        initialValue: playerId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'liturgy.parity.player'.tr(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'default',
                            child: Text('liturgy.parity.internalPlayer'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'associated',
                            child: Text('liturgy.parity.externalPlayer'.tr()),
                          ),
                          const DropdownMenuItem(
                            value: 'vlc',
                            child: Text('VLC'),
                          ),
                          const DropdownMenuItem(
                            value: 'mpv',
                            child: Text('mpv'),
                          ),
                          if (!{
                            'default',
                            'associated',
                            'vlc',
                            'mpv',
                          }.contains(playerId))
                            DropdownMenuItem(
                              value: playerId,
                              child: Text(playerId),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            setModalState(() => playerId = value);
                        },
                      ),

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
                        onChanged: (value) {
                          linkTimer?.cancel();
                          linkTimer = Timer(
                            const Duration(milliseconds: 600),
                            () async {
                              if (!open || !_isValidUrl(value)) return;
                              setModalState(() => loadingLink = true);
                              try {
                                final info = await LiturgyLinkRepositoryImpl()
                                    .info(value);
                                if (!open ||
                                    !ctx.mounted ||
                                    urlCtrl.text != value)
                                  return;
                                final patch = info.patch(
                                  name: nameCtrl.text,
                                  subtitle: descriptionCtrl.text,
                                  autoName: autoName,
                                  autoSubtitle: autoDescription,
                                );
                                setModalState(() {
                                  if (patch['name'] is String) {
                                    nameCtrl.text = patch['name'] as String;
                                    autoName = nameCtrl.text;
                                  }
                                  if (patch['subtitle'] is String) {
                                    descriptionCtrl.text =
                                        patch['subtitle'] as String;
                                    autoDescription = descriptionCtrl.text;
                                  }
                                  if (patch['durationMs'] is int) {
                                    durationMs = patch['durationMs'] as int;
                                    durationMinutes.value = durationMs ~/ 60000;
                                  }
                                });
                              } catch (_) {
                                /* metadados são opcionais; formulário continua offline */
                              } finally {
                                if (open && ctx.mounted)
                                  setModalState(() => loadingLink = false);
                              }
                            },
                          );
                        },
                      ),
                      if (loadingLink) const LinearProgressIndicator(),
                      const SizedBox(height: AppSpacing.s3),
                    ],

                    // Arquivo: video/images/pdf/ppt/other
                    if (_fileTypes.contains(type.value)) ...[
                      _FileSelectorCard(
                        filePath: filePathCtrl,
                        onPick: () async {
                          final fileType = type.value == LiturgyItemType.images
                              ? FileType.image
                              : type.value == LiturgyItemType.video
                              ? FileType.video
                              : FileType.any;
                          final files = type.value == LiturgyItemType.images
                              ? await FilePicker.pickFiles(type: fileType)
                              : [?await FilePicker.pickFile(type: fileType)];
                          if (files.isNotEmpty) {
                            paths = files
                                .map((f) => f.path)
                                .whereType<String>()
                                .toList();
                            final path = files.first.path;
                            // Duração automática de vídeo/áudio local (MP4).
                            var probed = 0;
                            if (path != null) {
                              probed = await MediaDurationReader.readMs(path);
                            }
                            setModalState(() {
                              filePathCtrl.text = path ?? '';
                              if (nameCtrl.text.isEmpty) {
                                nameCtrl.text = files.first.name;
                              }
                              if (probed > 0) {
                                durationMs = probed;
                                durationMinutes.value = probed ~/ 60000;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.s3),
                    ],

                    // Os mesmos tipos sem duração do desktop.
                    if (!LiturgyItemRules.withoutDuration.contains(type.value))
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
                                ? () => setModalState(() {
                                    durationMs = (durationMs - 60000).clamp(
                                      0,
                                      5940000,
                                    );
                                    durationMinutes.value = durationMs ~/ 60000;
                                  })
                                : null,
                          ),
                          Text(
                            LiturgyFormat.formatElapsed(durationMs),
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                          IconButton(
                            tooltip: 'common.increase'.tr(),
                            icon: const Icon(TablerIcons.plus, size: 18),
                            onPressed: durationMinutes.value < 99
                                ? () => setModalState(() {
                                    durationMs = (durationMs + 60000).clamp(
                                      0,
                                      5940000,
                                    );
                                    durationMinutes.value = durationMs ~/ 60000;
                                  })
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
                    if (type.value != LiturgyItemType.music &&
                        type.value != LiturgyItemType.annotation &&
                        type.value != LiturgyItemType.category)
                      TextField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'liturgy.parity.description'.tr(),
                        ),
                      ),
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

                  if (type.value == LiturgyItemType.category) ...[
                    TextField(
                      key: const Key('liturgy-category-start'),
                      controller: startTimeCtrl,
                      decoration: InputDecoration(
                        labelText: 'liturgy.fields.startTime'.tr(),
                        hintText: 'HH:MM',
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                    TextField(
                      key: const Key('liturgy-category-end'),
                      controller: endTimeCtrl,
                      decoration: InputDecoration(
                        labelText: 'liturgy.fields.endTime'.tr(),
                        hintText: 'HH:MM',
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
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
                            var name = nameCtrl.text.trim();
                            // Paridade app a60ddfd: edição de item de música
                            // importado (.slja/comunidade grava o título em
                            // subtitle ou name da música) não pode abrir/travar
                            // com título vazio — cascata subtitle → label.
                            if (name.isEmpty) {
                              name = existing?.subtitle.trim() ?? '';
                              if (name.isEmpty) name = subtitleCtrl.text.trim();
                            }
                            if (name.isEmpty &&
                                selectedMusicId.value == null &&
                                filePathCtrl.text.isEmpty &&
                                urlCtrl.text.isEmpty) {
                              return;
                            }
                            if (type.value == LiturgyItemType.category &&
                                (LiturgyFormat.normalizeTimeHHmm(
                                          startTimeCtrl.text,
                                        ) ==
                                        null ||
                                    (endTimeCtrl.text.trim().isNotEmpty &&
                                        LiturgyFormat.normalizeTimeHHmm(
                                              endTimeCtrl.text,
                                            ) ==
                                            null))) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'liturgy.fields.invalidTime'.tr(),
                                  ),
                                ),
                              );
                              return;
                            }
                            final selectedType = type.value!;
                            final wireType = LiturgyItem(
                              id: 'draft',
                              type: selectedType,
                              name: name,
                            ).toJson()['type'];
                            final cleanHtml = RichNotes.sanitize(
                              annotationHtml,
                            );
                            final item = LiturgyItem.fromJson({
                              ...?existing?.toJson(),
                              'id':
                                  existing?.id ??
                                  DateTime.now().microsecondsSinceEpoch
                                      .toString(),
                              'type': wireType,
                              'name': name.isNotEmpty
                                  ? name
                                  : selectedMusicLabel.value,
                              'subtitle':
                                  selectedType == LiturgyItemType.annotation
                                  ? RichNotes.plainText(cleanHtml)
                                  : descriptionCtrl.text.trim(),
                              'complementaryTitle': subtitleCtrl.text.trim(),
                              'musicMode': musicMode.value,
                              'playerId': playerId == 'default'
                                  ? null
                                  : playerId,
                              'filePaths': paths,
                              'filePath': filePathCtrl.text.trim(),
                              'categoryId':
                                  selectedType == LiturgyItemType.category
                                  ? null
                                  : category.value?.isEmpty == true
                                  ? null
                                  : category.value,
                              'startTime':
                                  selectedType == LiturgyItemType.category
                                  ? LiturgyFormat.normalizeTimeHHmm(
                                      startTimeCtrl.text,
                                    )
                                  : existing?.startTime,
                              'endTime':
                                  selectedType == LiturgyItemType.category
                                  ? LiturgyFormat.normalizeTimeHHmm(
                                      endTimeCtrl.text,
                                    )
                                  : existing?.endTime,
                              'durationMs':
                                  LiturgyItemRules.withoutDuration.contains(
                                    selectedType,
                                  )
                                  ? 0
                                  : durationMs,
                              'musicId': selectedMusicId.value,
                              'url': urlCtrl.text.trim(),
                              'notes': notesCtrl.text.trim(),
                              'notesHtml':
                                  selectedType == LiturgyItemType.annotation
                                  ? cleanHtml
                                  : existing?.notesHtml,
                              'titleColor':
                                  selectedType == LiturgyItemType.annotation
                                  ? titleColor
                                  : existing?.titleColor,
                              'scheduledRotationId':
                                  selectedType == LiturgyItemType.scheduled
                                  ? rotation.value
                                  : null,
                              'verseBookId': verseBook.value,
                              'verseChapter': verseChapter.value,
                              'verseNumbers': verseNumbers.text.trim(),
                            });
                            if (item.type == LiturgyItemType.music &&
                                    item.musicId == null ||
                                item.type == LiturgyItemType.verse &&
                                    (item.verseBookId == null ||
                                        item.verseChapter == null) ||
                                {
                                      LiturgyItemType.video,
                                      LiturgyItemType.pdf,
                                      LiturgyItemType.presentation,
                                    }.contains(item.type) &&
                                    filePathCtrl.text.trim().isEmpty ||
                                item.type == LiturgyItemType.images &&
                                    paths.isEmpty &&
                                    filePathCtrl.text.trim().isEmpty ||
                                {
                                      LiturgyItemType.site,
                                      LiturgyItemType.onlineVideo,
                                    }.contains(item.type) &&
                                    !_isValidUrl(urlCtrl.text)) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'liturgy.parity.incompleteItem'.tr(),
                                  ),
                                ),
                              );
                              return;
                            }
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
    ),
  );
  sheet.whenComplete(() {
    open = false;
    linkTimer?.cancel();
  });
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

bool _isValidUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return false;
  final uri = Uri.tryParse(
    RegExp(r'^https?://', caseSensitive: false).hasMatch(raw)
        ? raw
        : 'https://$raw',
  );
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.startsWith('.') ||
      uri.host.endsWith('.'))
    return false;
  return uri.host == 'localhost' || uri.host.contains('.');
}

class _DialogResourceOwner extends StatefulWidget {
  const _DialogResourceOwner({required this.onDispose, required this.child});
  final VoidCallback onDispose;
  final Widget child;
  @override
  State<_DialogResourceOwner> createState() => _DialogResourceOwnerState();
}

class _DialogResourceOwnerState extends State<_DialogResourceOwner> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
