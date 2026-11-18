import 'dart:async';
import 'package:louvorja_piano_mobile/core/services/liturgy/provai_catalog.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/provai_import.dart';
import 'package:louvorja_piano_mobile/domain/repositories/provai_repository.dart';
import 'package:louvorja_piano_mobile/data/repositories/provai_repository_impl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/scheduled_planning.dart';
import 'package:louvorja_piano_mobile/data/repositories/scheduled_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/scheduled_item.dart';

abstract class ScheduledEvent {
  const ScheduledEvent();
}

class ScheduledLoadRequested extends ScheduledEvent {
  const ScheduledLoadRequested();
}

class ScheduledRotationSelected extends ScheduledEvent {
  const ScheduledRotationSelected(this.id);
  final String id;
}

class ScheduledCategorySaved extends ScheduledEvent {
  const ScheduledCategorySaved(this.name, {this.id});
  final String name;
  final String? id;
}

class ScheduledCategoryDeleted extends ScheduledEvent {
  const ScheduledCategoryDeleted(this.id);
  final String id;
}

class ScheduledEntrySaved extends ScheduledEvent {
  const ScheduledEntrySaved(this.item);
  final ScheduledItem item;
}

class ScheduledEntryDeleted extends ScheduledEvent {
  const ScheduledEntryDeleted(this.id);
  final String id;
}

class ScheduledQuarterPasted extends ScheduledEvent {
  const ScheduledQuarterPasted(
    this.text, {
    required this.year,
    this.mapping = const {},
    this.autoCreate = true,
  });
  final String text;
  final int year;
  final Map<String, String> mapping;
  final bool autoCreate;
}

class ScheduledQuarterDuplicated extends ScheduledEvent {
  const ScheduledQuarterDuplicated(
    this.categoryId, {
    required this.from,
    required this.weeks,
  });
  final String categoryId;
  final DateTime from;
  final int weeks;
}

class ScheduledXmlImported extends ScheduledEvent {
  const ScheduledXmlImported(this.categories, this.items);
  final List<Map<String, String>> categories;
  final List<Map<String, String>> items;
}

class ScheduledProvaiRequested extends ScheduledEvent {
  const ScheduledProvaiRequested(this.language, this.year, this.quarter);
  final String language;
  final int year;
  final int quarter;
}

class ScheduledProvaiImported extends ScheduledEvent {
  const ScheduledProvaiImported(this.episodes, {this.onlyUpcoming = true});
  final List<ProvaiEpisode> episodes;
  final bool onlyUpcoming;
}

class ScheduledState {
  const ScheduledState({
    this.categories = const [],
    this.items = const [],
    this.selectedId,
    this.report,
    this.error = false,
    this.provaiSource,
    this.episodes = const [],
    this.busy = false,
    this.progress = '',
  });
  final List<ScheduledCategory> categories;
  final List<ScheduledItem> items;
  final String? selectedId;
  final QuarterPasteReport? report;
  final bool error;
  final ProvaiSource? provaiSource;
  final List<ProvaiEpisode> episodes;
  final bool busy;
  final String progress;
}

class ScheduledBloc extends Bloc<ScheduledEvent, ScheduledState> {
  ScheduledBloc(this.repository, {ProvaiRepository? provaiRepository})
    : provai = provaiRepository ?? ProvaiRepositoryImpl(),
      super(const ScheduledState()) {
    on<ScheduledLoadRequested>((event, emit) => emit(_load()));
    on<ScheduledRotationSelected>(
      (event, emit) => emit(_load(selectedId: event.id)),
    );
    on<ScheduledCategorySaved>((event, emit) async {
      try {
        final category = await repository.upsertCategory(
          id: event.id,
          name: event.name,
        );
        emit(_load(selectedId: category.id));
      } catch (_) {
        emit(_load(error: true));
      }
    });
    on<ScheduledCategoryDeleted>((event, emit) async {
      await repository.deleteCategory(event.id);
      emit(_load());
    });
    on<ScheduledEntrySaved>((event, emit) async {
      await repository.upsertItem(event.item);
      emit(_load(selectedId: event.item.categoryId));
    });
    on<ScheduledEntryDeleted>((event, emit) async {
      await repository.deleteItem(event.id);
      emit(_load());
    });
    on<ScheduledQuarterPasted>((event, emit) async {
      final report = await ScheduledPlanning(repository).paste(
        event.text,
        year: event.year,
        slotMapping: event.mapping,
        autoCreateSlots: event.autoCreate,
      );
      emit(_load(report: report));
    });
    on<ScheduledQuarterDuplicated>((event, emit) async {
      final count = await ScheduledPlanning(repository).duplicateQuarter(
        event.categoryId,
        from: event.from,
        weeks: event.weeks,
      );
      emit(
        _load(
          report: QuarterPasteReport(
            created: count,
            errors: const [],
            unmappedSlots: const [],
          ),
        ),
      );
    });
    on<ScheduledXmlImported>((event, emit) async {
      final count = await repository.importFromDelphi(
        categories: event.categories,
        items: event.items,
      );
      emit(
        _load(
          report: QuarterPasteReport(
            created: count,
            errors: const [],
            unmappedSlots: const [],
          ),
        ),
      );
    });
    on<ScheduledProvaiRequested>((event, emit) async {
      final source = ProvaiCatalog.source(
        event.language,
        event.year,
        event.quarter,
      );
      if (source == null) {
        emit(_load(error: true));
        return;
      }
      emit(_load(busy: true, source: source, episodes: const [], progress: ''));
      try {
        final episodes = await provai.episodes(source);
        if (!emit.isDone)
          emit(
            _load(
              busy: false,
              source: source,
              episodes: episodes,
              error: episodes.isEmpty,
            ),
          );
      } catch (_) {
        if (!emit.isDone) emit(_load(busy: false, error: true));
      }
    });
    on<ScheduledProvaiImported>((event, emit) async {
      final source = state.provaiSource;
      if (source == null || state.busy) return;
      emit(_load(busy: true, progress: ''));
      try {
        final report = await ProvaiImport(repository).apply(
          source,
          event.episodes,
          provai.download,
          onlyUpcoming: event.onlyUpcoming,
          onProgress: (index, total) {
            if (!emit.isDone)
              emit(_load(busy: true, progress: '$index / $total'));
          },
        );
        if (!emit.isDone)
          emit(
            _load(
              busy: false,
              selectedId: report.rotationId,
              report: QuarterPasteReport(
                created: report.created,
                errors: const [],
                unmappedSlots: const [],
              ),
              progress: '',
            ),
          );
      } catch (_) {
        if (!emit.isDone) emit(_load(busy: false, error: true, progress: ''));
      }
    });
    _changes = ScheduledRepository.changes.listen((_) {
      if (!isClosed) add(const ScheduledLoadRequested());
    });
  }
  final ScheduledRepository repository;
  final ProvaiRepository provai;
  late final StreamSubscription<void> _changes;
  ScheduledState _load({
    String? selectedId,
    QuarterPasteReport? report,
    bool error = false,
    bool? busy,
    ProvaiSource? source,
    List<ProvaiEpisode>? episodes,
    String? progress,
  }) {
    final categories = repository.loadCategories();
    final requested = selectedId ?? state.selectedId;
    final selected = categories.any((e) => e.id == requested)
        ? requested
        : categories.firstOrNull?.id;
    return ScheduledState(
      categories: categories,
      items: repository.loadItems()..sort((a, b) => a.date.compareTo(b.date)),
      selectedId: selected,
      report: report ?? state.report,
      error: error,
      busy: busy ?? state.busy,
      provaiSource: source ?? state.provaiSource,
      episodes: episodes ?? state.episodes,
      progress: progress ?? state.progress,
    );
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
