library;

import 'dart:async';

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'package:louvorja_piano_mobile/core/services/connectivity_service.dart';
import 'package:louvorja_piano_mobile/core/services/offline_library_filter.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_catalog_provider.dart';
import 'package:louvorja_piano_mobile/domain/repositories/hymn_repository.dart';

// --- Events ---

abstract class HymnsEvent {
  const HymnsEvent();
}

class HymnsLoadRequested extends HymnsEvent {}

class HymnsRefreshRequested extends HymnsEvent {}

/// Convite "Ver em Português": troca SÓ o catálogo (override pt),
/// a UI mantém o idioma do usuário.
class HymnsSeePortugueseRequested extends HymnsEvent {}

// --- States ---

abstract class HymnsState {
  const HymnsState();
}

class HymnsInitial extends HymnsState {}

class HymnsLoading extends HymnsState {}

class HymnsLoaded extends HymnsState {
  final List<AlbumCategory> categories;

  const HymnsLoaded(this.categories);
}

class HymnsError extends HymnsState {
  /// Código i18n da mensagem de erro (ex: 'errors.connection').
  final String code;

  const HymnsError(this.code);
}

/// Idioma sem catálogo na API (404 em `<lang>_categories`): NÃO é erro —
/// convite à comunidade para contribuir (paridade com o convite do desktop).
/// [previewCategories]: catálogo pt-BR real buscado em background para o
/// backdrop desfocado (não funcional, aria-hidden); vazio → mockup estático.
class HymnsCatalogInvite extends HymnsState {
  final List<AlbumCategory> previewCategories;

  const HymnsCatalogInvite({this.previewCategories = const []});
}

// --- BLoC ---

class HymnsBloc extends Bloc<HymnsEvent, HymnsState> {
  final HymnRepository _repository;

  /// Provider do catalogo em memoria para a busca global.
  /// Opcional: quando nulo, a busca usa fonte propria (fallback).
  final HymnCatalogProvider? catalogProvider;

  /// Porta offline opcional: quando fornecida E sem rede, o catálogo
  /// emitido é a BIBLIOTECA BAIXADA (offline-first), não o cache completo.
  final OfflineMusicPort? offlinePort;

  /// Consulta de conectividade injetável (testes); produção usa real.
  Future<bool> Function()? connectivityCheck;

  HymnsBloc(
    this._repository, {
    this.catalogProvider,
    this.offlinePort,
    this.connectivityCheck,
  }) : super(HymnsInitial()) {
    on<HymnsLoadRequested>(_onLoad);
    on<HymnsRefreshRequested>(_onRefresh);
    on<HymnsSeePortugueseRequested>(_onSeePortuguese);
  }

  /// Exposto para páginas filhas (AlbumDetailPage) buscarem hinos.
  HymnRepository get repository => _repository;

  Future<void> _onLoad(
    HymnsLoadRequested event,
    Emitter<HymnsState> emit,
  ) async {
    emit(HymnsLoading());
    try {
      final categories = await _repository.getCategories();
      // Sync do catálogo de busca NÃO bloqueia a UI: com 67 álbuns o loader
      // serial demorava minutos e a tela ficava em loading infinito
      // (bug 2026-08-16). A busca global preenche quando concluir.
      unawaited(_syncCatalog(categories));
      emit(HymnsLoaded(await _visibleCategories(categories)));
    } on LouvorjaApiException catch (e) {
      if (e.code == 'errors.notFound') {
        // Idioma sem catálogo (404 `<lang>_categories`): convite, não erro.
        // Catálogo pt-BR em background para o backdrop desfocado (não
        // bloqueia o convite; falha → preview vazio → mockup estático).
        final preview = await _repository.previewPortugueseCategories();
        emit(HymnsCatalogInvite(previewCategories: preview));
      } else {
        emit(HymnsError(e.code));
      }
    } catch (_) {
      emit(const HymnsError('errors.unknown'));
    }
  }

  Future<void> _onRefresh(
    HymnsRefreshRequested event,
    Emitter<HymnsState> emit,
  ) async {
    try {
      final categories = await _repository.getCategories();
      unawaited(_syncCatalog(categories));
      emit(HymnsLoaded(await _visibleCategories(categories)));
    } on LouvorjaApiException catch (e) {
      if (e.code == 'errors.notFound') {
        // Idioma sem catálogo (404 `<lang>_categories`): convite, não erro.
        final preview = await _repository.previewPortugueseCategories();
        emit(HymnsCatalogInvite(previewCategories: preview));
      } else {
        emit(HymnsError(e.code));
      }
    } catch (_) {
      emit(const HymnsError('errors.unknown'));
    }
  }

  /// Convite → catálogo em Português: override pt no repositório e
  /// recarrega. A UI NÃO troca de idioma (só o catálogo).
  Future<void> _onSeePortuguese(
    HymnsSeePortugueseRequested event,
    Emitter<HymnsState> emit,
  ) async {
    emit(HymnsLoading());
    try {
      _repository.setCatalogLanguage('pt');
      final categories = await _repository.getCategories();
      unawaited(_syncCatalog(categories));
      emit(HymnsLoaded(await _visibleCategories(categories)));
    } on LouvorjaApiException catch (e) {
      emit(HymnsError(e.code));
    } catch (_) {
      emit(const HymnsError('errors.unknown'));
    }
  }

  /// Offline: apenas a biblioteca baixada. Online: catálogo completo.
  Future<List<AlbumCategory>> _visibleCategories(
    List<AlbumCategory> categories,
  ) async {
    final port = offlinePort;
    if (port == null) return categories;
    final offline = connectivityCheck != null
        ? !(await connectivityCheck!())
        : !(await ConnectivityService().isConnected);
    if (!offline) return categories;
    return OfflineLibraryFilter.filterCategories(
      categories: categories,
      offline: port,
    );
  }

  /// Popula o provider de catalogo (busca global) sem bloquear o emit
  /// do estado: usa o mesmo repository para carregar hinos por album.
  Future<void> _syncCatalog(List<dynamic> categories) async {
    final provider = catalogProvider;
    if (provider == null) return;
    try {
      await provider.setCatalog(
        categories.cast(),
        hymnLoader: (albumId) => _repository.getHymnsByAlbum(albumId),
      );
    } catch (_) {
      // Falha no catalogo de busca nao derruba a UI de hinos.
    }
  }
}
