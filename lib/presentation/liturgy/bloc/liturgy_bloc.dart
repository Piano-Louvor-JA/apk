library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_liturgy.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_item_rules.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

// --- Events ---

abstract class LiturgyEvent {
  const LiturgyEvent();
}

class LiturgyLoadRequested extends LiturgyEvent {
  final LiturgyWeekday day;
  const LiturgyLoadRequested(this.day);
}

class LiturgyDayChanged extends LiturgyEvent {
  final LiturgyWeekday day;
  // coverage:ignore-line
  const LiturgyDayChanged(this.day);
}

class LiturgyAddItem extends LiturgyEvent {
  final LiturgyItem item;
  // coverage:ignore-line
  const LiturgyAddItem(this.item);
}

class LiturgyUpdateItem extends LiturgyEvent {
  final LiturgyItem item;
  // coverage:ignore-line
  const LiturgyUpdateItem(this.item);
}

class LiturgyDeleteItem extends LiturgyEvent {
  final String itemId;
  // coverage:ignore-line
  const LiturgyDeleteItem(this.itemId);
}

class LiturgyToggleDone extends LiturgyEvent {
  final String itemId;
  // coverage:ignore-line
  const LiturgyToggleDone(this.itemId);
}

class LiturgyReorderItems extends LiturgyEvent {
  final int oldIndex;
  final int newIndex;
  // coverage:ignore-line
  const LiturgyReorderItems(this.oldIndex, this.newIndex);
}

class LiturgyCloneDay extends LiturgyEvent {
  final LiturgyWeekday from;
  // coverage:ignore-line
  const LiturgyCloneDay(this.from);
}

class LiturgyClearDay extends LiturgyEvent {}

class LiturgyLockToggled extends LiturgyEvent {}

class LiturgyItemsReordered extends LiturgyEvent {
  final List<LiturgyItem> items;
  const LiturgyItemsReordered(this.items);
}

class LiturgyUpdateNotes extends LiturgyEvent {
  final String notes;
  const LiturgyUpdateNotes(this.notes);
}

class LiturgySelectItem extends LiturgyEvent {
  const LiturgySelectItem(this.id);
  final String id;
}

/// Nenhum item destacado (toque na linha da categoria sem nada tocando).
class LiturgyClearSelection extends LiturgyEvent {}

class LiturgyMarkDone extends LiturgyEvent {
  const LiturgyMarkDone(this.id);
  final String id;
}

class LiturgyReloadRequested extends LiturgyEvent {}

class LiturgyCustomSelected extends LiturgyEvent {
  final String id;
  const LiturgyCustomSelected(this.id);
}

class LiturgyCustomCreated extends LiturgyEvent {
  final String name;
  const LiturgyCustomCreated(this.name);
}

class LiturgyCustomRenamed extends LiturgyEvent {
  final String id;
  final String name;
  const LiturgyCustomRenamed(this.id, this.name);
}

class LiturgyCustomDeleted extends LiturgyEvent {
  final String id;
  const LiturgyCustomDeleted(this.id);
}

class LiturgyCloneSource extends LiturgyEvent {
  final String key;
  const LiturgyCloneSource(this.key);
}

class LiturgySessionTimesChanged extends LiturgyEvent {
  final String? startTime;
  final String? endTime;
  const LiturgySessionTimesChanged({this.startTime, this.endTime});
}

const _unchangedTime = Object();

// --- State ---

class LiturgySessionClockStarted extends LiturgyEvent {}

class LiturgySessionClockStopped extends LiturgyEvent {}

abstract class LiturgyState {
  const LiturgyState();
}

class LiturgyInitial extends LiturgyState {}

class LiturgyLoaded extends LiturgyState {
  final LiturgyWeekday selectedDay;
  final List<LiturgyItem> items;
  final String notes;
  final bool locked;
  final String? customId;
  final String? selectedItemId;
  final DateTime? sessionStartedAt;
  final List<CustomLiturgy> customLiturgies;
  final String? startTime;
  final String? endTime;
  String get contextKey =>
      customId == null ? selectedDay.name : 'custom:$customId';
  String? get customName =>
      customLiturgies.where((e) => e.id == customId).firstOrNull?.name;

  const LiturgyLoaded({
    required this.selectedDay,
    required this.items,
    required this.notes,
    this.locked = false,
    this.customId,
    this.selectedItemId,
    this.sessionStartedAt,
    this.customLiturgies = const [],
    this.startTime,
    this.endTime,
  });

  LiturgyLoaded copyWith({
    LiturgyWeekday? selectedDay,
    List<LiturgyItem>? items,
    String? notes,
    bool? locked,
    List<CustomLiturgy>? customLiturgies,
    Object? selectedItemId = _unchangedTime,
    Object? sessionStartedAt = _unchangedTime,
    Object? startTime = _unchangedTime,
    Object? endTime = _unchangedTime,
  }) {
    return LiturgyLoaded(
      selectedDay: selectedDay ?? this.selectedDay,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      locked: locked ?? this.locked,
      selectedItemId: identical(selectedItemId, _unchangedTime)
          ? this.selectedItemId
          : selectedItemId as String?,
      sessionStartedAt: identical(sessionStartedAt, _unchangedTime)
          ? this.sessionStartedAt
          : sessionStartedAt as DateTime?,
      customId: customId,
      customLiturgies: customLiturgies ?? this.customLiturgies,
      startTime: identical(startTime, _unchangedTime)
          ? this.startTime
          : startTime as String?,
      endTime: identical(endTime, _unchangedTime)
          ? this.endTime
          : endTime as String?,
    );
  }
}

// --- Bloc ---

class LiturgyBloc extends Bloc<LiturgyEvent, LiturgyState> {
  final LiturgyRepository _repo;

  LiturgyBloc(this._repo) : super(LiturgyInitial()) {
    on<LiturgyLoadRequested>(_onLoad);
    on<LiturgyDayChanged>(_onDayChanged);
    on<LiturgyAddItem>(_onAddItem);
    on<LiturgyUpdateItem>(_onUpdateItem);
    on<LiturgyDeleteItem>(_onDeleteItem);
    on<LiturgyToggleDone>(_onToggleDone);
    on<LiturgyReorderItems>(_onReorder);
    on<LiturgyCloneDay>(_onCloneDay);
    on<LiturgyClearDay>(_onClearDay);
    on<LiturgyUpdateNotes>(_onUpdateNotes);
    on<LiturgyLockToggled>(_onToggleLock);
    on<LiturgyItemsReordered>(_onItemsReordered);
    on<LiturgySelectItem>((event, emit) async {
      final current = state;
      if (current is! LiturgyLoaded) return;
      final item = current.items
          .where((item) => item.id == event.id)
          .firstOrNull;
      if (item == null || item.done && !LiturgyItemRules.keepsControls(item))
        return;
      final now = DateTime.now();
      final start =
          current.startTime ??
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      emit(
        current.copyWith(
          selectedItemId: event.id,
          startTime: start,
          sessionStartedAt: current.sessionStartedAt ?? now,
        ),
      );
      if (current.startTime == null)
        await _repo.writeSessionTimes(
          current.contextKey,
          startTime: start,
          endTime: current.endTime,
        );
    });
    on<LiturgyClearSelection>((event, emit) {
      final current = state;
      if (current is LiturgyLoaded && current.selectedItemId != null) {
        emit(current.copyWith(selectedItemId: null));
      }
    });
    on<LiturgySessionClockStarted>((event, emit) async {
      final current = state;
      if (current is! LiturgyLoaded) return;
      final now = DateTime.now();
      final start =
          current.startTime ??
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      emit(current.copyWith(startTime: start, sessionStartedAt: now));
      if (current.startTime == null)
        await _repo.writeSessionTimes(
          current.contextKey,
          startTime: start,
          endTime: current.endTime,
        );
    });
    on<LiturgySessionClockStopped>((event, emit) {
      final current = state;
      if (current is LiturgyLoaded)
        emit(current.copyWith(sessionStartedAt: null));
    });
    on<LiturgyMarkDone>((event, emit) {
      final current = state;
      if (current is LiturgyLoaded &&
          current.items.any((e) => e.id == event.id && !e.done)) {
        _onToggleDone(LiturgyToggleDone(event.id), emit);
      }
    });
    on<LiturgyReloadRequested>((event, emit) {
      final current = state;
      if (current is LiturgyLoaded)
        emit(_loaded(current.selectedDay, customId: current.customId));
    });
    on<LiturgyCustomSelected>((event, emit) {
      final current = state;
      emit(
        _loaded(
          current is LiturgyLoaded
              ? current.selectedDay
              : LiturgyWeekday.sunday,
          customId: event.id,
        ),
      );
    });
    on<LiturgyCustomCreated>((event, emit) async {
      final current = state;
      final custom = await _repo.createCustom(event.name);
      emit(
        _loaded(
          current is LiturgyLoaded
              ? current.selectedDay
              : LiturgyWeekday.sunday,
          customId: custom.id,
        ),
      );
    });
    on<LiturgyCustomRenamed>((event, emit) async {
      await _repo.renameCustom(event.id, event.name);
      final current = state;
      if (current is LiturgyLoaded)
        emit(_loaded(current.selectedDay, customId: current.customId));
    });
    on<LiturgyCustomDeleted>((event, emit) async {
      await _repo.deleteCustom(event.id);
      final current = state;
      if (current is LiturgyLoaded)
        emit(
          _loaded(
            current.selectedDay,
            customId: current.customId == event.id
                ? _repo.loadCustomLiturgies().firstOrNull?.id
                : current.customId,
          ),
        );
    });
    on<LiturgyCloneSource>((event, emit) async {
      final current = state;
      if (current is! LiturgyLoaded ||
          current.items.isNotEmpty ||
          current.contextKey == event.key)
        return;
      await _repo.cloneContext(event.key, current.contextKey);
      if (state is LiturgyLoaded &&
          (state as LiturgyLoaded).contextKey == current.contextKey)
        emit(_loaded(current.selectedDay, customId: current.customId));
    });
    on<LiturgySessionTimesChanged>((event, emit) async {
      final current = state;
      if (current is! LiturgyLoaded) return;
      await _repo.writeSessionTimes(
        current.contextKey,
        startTime: event.startTime,
        endTime: event.endTime,
      );
      if (state is LiturgyLoaded &&
          (state as LiturgyLoaded).contextKey == current.contextKey)
        emit(_loaded(current.selectedDay, customId: current.customId));
    });
  }

  LiturgyRepository get repository => _repo;

  LiturgyLoaded _loaded(LiturgyWeekday day, {String? customId}) {
    final customs = _repo.loadCustomLiturgies();
    if (customId != null && !customs.any((e) => e.id == customId))
      customId = null;
    final key = customId == null ? day.name : 'custom:$customId';
    final times = _repo.readSessionTimes(key);
    final items = _repo.readItems(key);
    final previous = state;
    final selection =
        previous is LiturgyLoaded &&
            previous.contextKey == key &&
            items.any(
              (item) =>
                  item.id == previous.selectedItemId &&
                  (!item.done || LiturgyItemRules.keepsControls(item)),
            )
        ? previous.selectedItemId
        : null;
    return LiturgyLoaded(
      selectedDay: day,
      customId: customId,
      customLiturgies: customs,
      items: items,
      selectedItemId: selection,
      sessionStartedAt: previous is LiturgyLoaded && previous.contextKey == key
          ? previous.sessionStartedAt
          : null,
      notes: _repo.readNotes(key),
      locked: _repo.readLock(key),
      startTime: times['startTime'] as String?,
      endTime: times['endTime'] as String?,
    );
  }

  void _onLoad(LiturgyLoadRequested event, Emitter<LiturgyState> emit) =>
      emit(_loaded(event.day));
  void _onDayChanged(LiturgyDayChanged event, Emitter<LiturgyState> emit) =>
      emit(_loaded(event.day));

  void _onAddItem(LiturgyAddItem event, Emitter<LiturgyState> emit) {
    final state = this.state;
    if (state is! LiturgyLoaded) return;
    final items = LiturgyItemRules.insert(state.items, event.item);
    _repo.writeItems(state.contextKey, items);
    emit(state.copyWith(items: items));
  }

  void _onUpdateItem(LiturgyUpdateItem event, Emitter<LiturgyState> emit) {
    final state = this.state;
    if (state is! LiturgyLoaded) return;
    if (state.locked) return;
    final previous = state.items
        .where((e) => e.id == event.item.id)
        .firstOrNull;
    if (previous == null) return;
    final items =
        previous.categoryId != event.item.categoryId &&
            event.item.categoryId != null
        ? LiturgyItemRules.insert(
            state.items.where((e) => e.id != event.item.id).toList(),
            event.item,
          )
        : state.items
              .map((e) => e.id == event.item.id ? event.item : e)
              .toList();
    _repo.writeItems(state.contextKey, items);
    emit(state.copyWith(items: items));
  }

  void _onDeleteItem(LiturgyDeleteItem event, Emitter<LiturgyState> emit) {
    final state = this.state;
    if (state is! LiturgyLoaded) return;
    if (state.locked) return;
    final items = state.items.where((e) => e.id != event.itemId).toList();
    // Tambem remove sub-itens da categoria removida
    final children = items.where((e) => e.categoryId == event.itemId).toList();
    for (final child in children) {
      items.remove(child);
    }
    _repo.writeItems(state.contextKey, items);
    emit(state.copyWith(items: items));
  }

  void _onToggleDone(LiturgyToggleDone event, Emitter<LiturgyState> emit) {
    final state = this.state;
    if (state is! LiturgyLoaded) return;
    final target = state.items.where((e) => e.id == event.itemId).firstOrNull;
    if (target == null) return;
    var items = state.items.map((item) {
      if (item.id == target.id ||
          (target.type == LiturgyItemType.category &&
              item.categoryId == target.id)) {
        return item.copyWith(done: !target.done);
      }
      return item;
    }).toList();
    if (target.type != LiturgyItemType.category) {
      items = items.map((item) {
        if (item.type != LiturgyItemType.category) return item;
        final children = items.where(
          (child) =>
              child.type != LiturgyItemType.category &&
              child.categoryId == item.id,
        );
        return children.isEmpty
            ? item
            : item.copyWith(done: children.every((child) => child.done));
      }).toList();
    }
    _repo.writeItems(state.contextKey, items);
    emit(
      state.copyWith(
        items: items,
        selectedItemId:
            items.any(
              (e) =>
                  e.id == state.selectedItemId &&
                  (!e.done || LiturgyItemRules.keepsControls(e)),
            )
            ? state.selectedItemId
            : null,
      ),
    );
  }

  void _onReorder(LiturgyReorderItems event, Emitter<LiturgyState> emit) {
    final state = this.state;
    if (state is! LiturgyLoaded) return;
    final items = LiturgyItemRules.reorder(
      state.items,
      event.oldIndex,
      event.newIndex,
    );
    _repo.writeItems(state.contextKey, items);
    emit(state.copyWith(items: items));
  }

  Future<void> _onCloneDay(
    LiturgyCloneDay event,
    Emitter<LiturgyState> emit,
  ) async {
    final current = state;
    if (current is! LiturgyLoaded || current.items.isNotEmpty) return;
    await _repo.cloneContext(event.from.name, current.contextKey);
    if (state is LiturgyLoaded &&
        (state as LiturgyLoaded).contextKey == current.contextKey)
      emit(_loaded(current.selectedDay, customId: current.customId));
  }

  Future<void> _onClearDay(
    LiturgyClearDay event,
    Emitter<LiturgyState> emit,
  ) async {
    final current = state;
    if (current is! LiturgyLoaded || current.locked) return;
    await _repo.writeItems(current.contextKey, []);
    if (state is LiturgyLoaded &&
        (state as LiturgyLoaded).contextKey == current.contextKey)
      emit(_loaded(current.selectedDay, customId: current.customId));
  }

  void _onUpdateNotes(LiturgyUpdateNotes event, Emitter<LiturgyState> emit) {
    final state = this.state;
    if (state is! LiturgyLoaded) return;
    _repo.writeNotes(state.contextKey, event.notes);
    emit(state.copyWith(notes: event.notes));
  }

  void _onToggleLock(LiturgyLockToggled event, Emitter<LiturgyState> emit) {
    final state = this.state;
    if (state is! LiturgyLoaded) return;
    final locked = !state.locked;
    _repo.writeLock(state.contextKey, locked);
    emit(state.copyWith(locked: locked));
  }

  void _onItemsReordered(
    LiturgyItemsReordered event,
    Emitter<LiturgyState> emit,
  ) {
    final state = this.state;
    if (state is! LiturgyLoaded) return;
    _repo.writeItems(state.contextKey, event.items);
    emit(state.copyWith(items: event.items));
  }
}
