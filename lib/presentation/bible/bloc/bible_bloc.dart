library;

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:louvorja_piano_mobile/core/utils/scripture_format.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/repositories/bible_repository.dart';

// --- Events ---

abstract class BibleEvent {
  const BibleEvent();
}

class BibleBootstrap extends BibleEvent {}

class BibleSelectVersion extends BibleEvent {
  final int versionId;
  const BibleSelectVersion(this.versionId);
}

class BibleSelectBook extends BibleEvent {
  final int bookId;
  const BibleSelectBook(this.bookId);
}

class BibleSelectChapter extends BibleEvent {
  final int chapter;
  const BibleSelectChapter(this.chapter);
}

class BibleSelectVerse extends BibleEvent {
  final int verseNumber;
  // coverage:ignore-line
  const BibleSelectVerse(this.verseNumber);
}

/// Seleção múltipla direta (input de referência "gn 1:1-3", "jo 2:3,5").
class BibleSelectVerses extends BibleEvent {
  final List<int> verses;
  const BibleSelectVerses(this.verses);
}

class BibleClearSelection extends BibleEvent {}

/// Navega para versiculo anterior (+delta) ou proximo (-delta).
/// Cruza capitulos automaticamente quando chega nos extremos.
class BibleNavigateVerse extends BibleEvent {
  final int delta; // -1 = anterior, +1 = proximo
  const BibleNavigateVerse(this.delta);
}

// --- States ---

abstract class BibleState {
  const BibleState();
}

class BibleInitial extends BibleState {}

class BibleLoading extends BibleState {}

class BibleError extends BibleState {
  final String code;
  const BibleError(this.code);
}

class BibleLoaded extends BibleState {
  final List<BibleBook> books;
  final List<BibleVersion> versions;
  final int selectedVersionId;
  final int selectedBookId;
  final int selectedChapter;
  final Map<String, String> verses;
  final List<int> selectedVerses;

  const BibleLoaded({
    required this.books,
    required this.versions,
    required this.selectedVersionId,
    required this.selectedBookId,
    required this.selectedChapter,
    required this.verses,
    required this.selectedVerses,
  });

  BibleBook? get selectedBook =>
      books.where((b) => b.id == selectedBookId).firstOrNull;

  BibleVersion? get selectedVersion =>
      versions.where((v) => v.id == selectedVersionId).firstOrNull;

  String get locationLabel {
    final book = selectedBook;
    final version = selectedVersion;
    if (book == null) return '';
    return ScriptureFormat.formatReference(
      bookName: book.name,
      chapter: selectedChapter,
      verses: selectedVerses,
      versionAbbreviation: version?.abbreviation,
    );
  }

  BibleLoaded copyWith({
    List<BibleBook>? books,
    List<BibleVersion>? versions,
    int? selectedVersionId,
    int? selectedBookId,
    int? selectedChapter,
    Map<String, String>? verses,
    List<int>? selectedVerses,
  }) {
    return BibleLoaded(
      books: books ?? this.books,
      versions: versions ?? this.versions,
      selectedVersionId: selectedVersionId ?? this.selectedVersionId,
      selectedBookId: selectedBookId ?? this.selectedBookId,
      selectedChapter: selectedChapter ?? this.selectedChapter,
      verses: verses ?? this.verses,
      selectedVerses: selectedVerses ?? this.selectedVerses,
    );
  }
}

// --- BLoC ---

class BibleBloc extends Bloc<BibleEvent, BibleState> {
  final BibleRepository _repository;

  BibleBloc(this._repository) : super(BibleInitial()) {
    on<BibleBootstrap>(_onBootstrap);
    on<BibleSelectVersion>(_onSelectVersion);
    on<BibleSelectBook>(_onSelectBook);
    on<BibleSelectChapter>(_onSelectChapter);
    on<BibleSelectVerse>(_onSelectVerse);
    on<BibleSelectVerses>(_onSelectVerses);
    on<BibleClearSelection>(_onClearSelection);
    on<BibleNavigateVerse>(_onNavigateVerse);
  }

  BibleRepository get repository => _repository;

  Future<void> _onBootstrap(
    BibleBootstrap event,
    Emitter<BibleState> emit,
  ) async {
    emit(BibleLoading());
    try {
      // Sequencial para respeitar rate limit
      final books = await _repository.getBooks();
      final versions = await _repository.getVersions();

      if (books.isEmpty || versions.isEmpty) {
        emit(const BibleError('bible.errors.loadCatalogFailed'));
        return;
      }

      final versionId = ScriptureFormat.pickDefaultVersionId(
        versions
            .map(
              (v) => BibleVersionDef(
                id: v.id,
                abbreviation: v.abbreviation,
                name: v.name,
              ),
            )
            .toList(),
        null,
      );

      final firstBook = books.first;
      final verses = await _repository.getChapter(
        versionId ?? versions.first.id,
        firstBook.id,
        1,
      );

      emit(
        BibleLoaded(
          books: books,
          versions: versions,
          // coverage:ignore-line
          selectedVersionId: versionId ?? versions.first.id,
          selectedBookId: firstBook.id,
          selectedChapter: 1,
          verses: verses,
          selectedVerses: const [],
        ),
      );
    } on LouvorjaApiException catch (e) {
      emit(BibleError(e.code));
    } catch (_) {
      emit(const BibleError('bible.errors.loadCatalogFailed'));
    }
  }

  Future<void> _onSelectVersion(
    BibleSelectVersion event,
    Emitter<BibleState> emit,
  ) async {
    final state = this.state;
    if (state is! BibleLoaded) return;

    try {
      final verses = await _repository.getChapter(
        event.versionId,
        state.selectedBookId,
        state.selectedChapter,
      );
      emit(
        state.copyWith(
          selectedVersionId: event.versionId,
          verses: verses,
          selectedVerses: const [],
        ),
      );
    } on LouvorjaApiException catch (e) {
      emit(BibleError(e.code));
    } catch (_) {
      // coverage:ignore-line
      emit(const BibleError('bible.errors.loadChapterFailed'));
    }
  }

  Future<void> _onSelectBook(
    BibleSelectBook event,
    Emitter<BibleState> emit,
  ) async {
    final state = this.state;
    if (state is! BibleLoaded) return;

    final book = state.books.where((b) => b.id == event.bookId).firstOrNull;
    if (book == null) return;

    final chapter = state.selectedChapter > book.chapters
        // coverage:ignore-line
        ? book.chapters
        : (state.selectedChapter < 1 ? 1 : state.selectedChapter);

    try {
      final verses = await _repository.getChapter(
        state.selectedVersionId,
        event.bookId,
        chapter,
      );
      emit(
        state.copyWith(
          selectedBookId: event.bookId,
          selectedChapter: chapter,
          verses: verses,
          selectedVerses: const [],
        ),
      );
    } on LouvorjaApiException catch (e) {
      emit(BibleError(e.code));
    } catch (_) {
      // coverage:ignore-line
      emit(const BibleError('bible.errors.loadChapterFailed'));
    }
  }

  Future<void> _onSelectChapter(
    BibleSelectChapter event,
    Emitter<BibleState> emit,
  ) async {
    final state = this.state;
    if (state is! BibleLoaded) return;
    if (event.chapter < 1) return;

    final book = state.selectedBook;
    final maxChapter = book?.chapters ?? event.chapter;
    final next = event.chapter > maxChapter ? maxChapter : event.chapter;
    if (next == state.selectedChapter) return;

    try {
      final verses = await _repository.getChapter(
        state.selectedVersionId,
        state.selectedBookId,
        next,
      );
      emit(
        state.copyWith(
          selectedChapter: next,
          verses: verses,
          selectedVerses: const [],
        ),
      );
    } on LouvorjaApiException catch (e) {
      emit(BibleError(e.code));
    } catch (_) {
      // coverage:ignore-line
      emit(const BibleError('bible.errors.loadChapterFailed'));
    }
  }

  void _onSelectVerse(BibleSelectVerse event, Emitter<BibleState> emit) {
    final state = this.state;
    if (state is! BibleLoaded) return;

    // Mobile: tap simples substitui selecao (nao acumula)
    emit(state.copyWith(selectedVerses: [event.verseNumber]));
  }

  void _onSelectVerses(BibleSelectVerses event, Emitter<BibleState> emit) {
    final state = this.state;
    if (state is! BibleLoaded) return;
    final verses = event.verses.where((v) => v >= 1).toSet().toList()..sort();
    emit(state.copyWith(selectedVerses: verses));
  }

  void _onClearSelection(BibleClearSelection event, Emitter<BibleState> emit) {
    final state = this.state;
    if (state is! BibleLoaded) return;

    emit(state.copyWith(selectedVerses: const []));
  }

  Future<void> _onNavigateVerse(
    BibleNavigateVerse event,
    Emitter<BibleState> emit,
  ) async {
    final state = this.state;
    if (state is! BibleLoaded) return;
    if (state.selectedVerses.isEmpty) return;

    final currentVerse = state.selectedVerses.first;
    final verseKeys =
        state.verses.keys
            .map((k) => int.tryParse(k) ?? 0)
            .where((v) => v > 0)
            .toList()
          ..sort();
    if (verseKeys.isEmpty) return;

    final book = state.selectedBook;
    if (book == null) return;

    final currentIndex = verseKeys.indexOf(currentVerse);
    if (currentIndex == -1) return;

    final newIndex = currentIndex + event.delta;

    if (newIndex >= 0 && newIndex < verseKeys.length) {
      // Mesmo capitulo: so move o versiculo selecionado
      emit(state.copyWith(selectedVerses: [verseKeys[newIndex]]));
      return;
    }

    // Cruzar para outro capitulo
    if (newIndex < 0 && state.selectedChapter > 1) {
      // Capitulo anterior -- carregar e selecionar ultimo versiculo
      await _loadChapterAndSelect(state, state.selectedChapter - 1, 999, emit);
    } else if (newIndex >= verseKeys.length &&
        state.selectedChapter < book.chapters) {
      // Proximo capitulo -- carregar e selecionar primeiro versiculo
      await _loadChapterAndSelect(state, state.selectedChapter + 1, 1, emit);
    }
  }

  Future<void> _loadChapterAndSelect(
    BibleLoaded state,
    int chapter,
    int verseTarget,
    Emitter<BibleState> emit,
  ) async {
    try {
      final verses = await _repository.getChapter(
        state.selectedVersionId,
        state.selectedBookId,
        chapter,
      );
      final keys =
          verses.keys
              .map((k) => int.tryParse(k) ?? 0)
              .where((v) => v > 0)
              .toList()
            ..sort();
      if (keys.isEmpty) return;
      final target = verseTarget == 999 ? keys.last : keys.first;
      emit(
        state.copyWith(
          selectedChapter: chapter,
          verses: verses,
          selectedVerses: [target],
        ),
      );
      // coverage:ignore-start
    } on LouvorjaApiException catch (e) {
      emit(BibleError(e.code));
    } catch (_) {
      emit(const BibleError('bible.errors.loadChapterFailed'));
    }
    // coverage:ignore-end
  }
}
