import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/model/instrument.dart';
import 'package:kiteconnectclient/model/watchlist.dart';
import 'package:kiteconnectclient/repository/watchlist_repo.dart';
import 'package:kiteconnectclient/services/instrument_sync_service.dart';
import 'package:meta/meta.dart';

part 'watchlist_event.dart';
part 'watchlist_state.dart';

class WatchlistBloc extends Bloc<WatchlistEvent, WatchlistState> {
  WatchlistBloc({
    WatchlistRepository? repository,
    InstrumentSyncService? syncService,
  }) : _repository = repository ?? WatchlistRepository(),
       _syncService = syncService ?? InstrumentSyncService.instance,
       super(const WatchlistState()) {
    on<WatchlistStarted>(_onStarted);
    on<WatchlistSelected>(_onSelected);
    on<WatchlistCreated>(_onCreated);
    on<WatchlistRenamed>(_onRenamed);
    on<WatchlistDeleted>(_onDeleted);
    on<WatchlistInstrumentToggled>(_onInstrumentToggled);
    on<WatchlistInstrumentRemoved>(_onInstrumentRemoved);
    on<WatchlistRefreshed>(_onRefreshed);

    _syncSubscription = _syncService.statusStream.listen((status) {
      if (status.phase == InstrumentSyncPhase.ready && status.hasInstruments) {
        add(const WatchlistRefreshed());
      }
    });
  }

  final WatchlistRepository _repository;
  final InstrumentSyncService _syncService;
  StreamSubscription<InstrumentSyncStatus>? _syncSubscription;

  Future<void> _onStarted(
    WatchlistStarted event,
    Emitter<WatchlistState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await _reloadAll(emit);
  }

  Future<void> _onSelected(
    WatchlistSelected event,
    Emitter<WatchlistState> emit,
  ) async {
    if (event.watchlistId == state.selectedWatchlistId) return;
    final items = await _repository.getWatchlistItems(event.watchlistId);
    emit(
      state.copyWith(
        selectedWatchlistId: event.watchlistId,
        activeItems: items,
        clearError: true,
      ),
    );
  }

  Future<void> _onCreated(
    WatchlistCreated event,
    Emitter<WatchlistState> emit,
  ) async {
    final trimmed = event.name.trim();
    if (trimmed.isEmpty) return;

    try {
      final created = await _repository.createWatchlist(trimmed);
      if (event.initialInstrument != null) {
        await _repository.addInstrument(
          watchlistId: created.id,
          instrument: event.initialInstrument!,
        );
      }
      await _reloadAll(
        emit,
        preferredWatchlistId: event.selectAfterCreate
            ? created.id
            : state.selectedWatchlistId,
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRenamed(
    WatchlistRenamed event,
    Emitter<WatchlistState> emit,
  ) async {
    await _repository.renameWatchlist(
      watchlistId: event.watchlistId,
      newName: event.newName,
    );
    await _reloadAll(emit, preferredWatchlistId: state.selectedWatchlistId);
  }

  Future<void> _onDeleted(
    WatchlistDeleted event,
    Emitter<WatchlistState> emit,
  ) async {
    await _repository.deleteWatchlist(event.watchlistId);
    final nextId = event.watchlistId == state.selectedWatchlistId
        ? null
        : state.selectedWatchlistId;
    await _reloadAll(emit, preferredWatchlistId: nextId);
  }

  Future<void> _onInstrumentToggled(
    WatchlistInstrumentToggled event,
    Emitter<WatchlistState> emit,
  ) async {
    final exists = state.isInWatchlist(
      event.watchlistId,
      event.instrument.instrumentToken,
    );
    if (exists) {
      await _repository.removeInstrument(
        watchlistId: event.watchlistId,
        instrumentToken: event.instrument.instrumentToken,
      );
    } else {
      await _repository.addInstrument(
        watchlistId: event.watchlistId,
        instrument: event.instrument,
      );
    }
    await _reloadAll(emit, preferredWatchlistId: state.selectedWatchlistId);
  }

  Future<void> _onInstrumentRemoved(
    WatchlistInstrumentRemoved event,
    Emitter<WatchlistState> emit,
  ) async {
    await _repository.removeInstrument(
      watchlistId: event.watchlistId,
      instrumentToken: event.instrumentToken,
    );
    await _reloadAll(emit, preferredWatchlistId: state.selectedWatchlistId);
  }

  Future<void> _onRefreshed(
    WatchlistRefreshed event,
    Emitter<WatchlistState> emit,
  ) async {
    await _reloadAll(emit, preferredWatchlistId: state.selectedWatchlistId);
  }

  Future<void> _reloadAll(
    Emitter<WatchlistState> emit, {
    int? preferredWatchlistId,
  }) async {
    try {
      final watchlists = await _repository.getWatchlists();
      final membership = await _repository.getMembershipByWatchlist();

      int? activeId = preferredWatchlistId ?? state.selectedWatchlistId;
      if (activeId == null || !watchlists.any((w) => w.id == activeId)) {
        activeId = watchlists.isNotEmpty ? watchlists.first.id : null;
      }

      final items = activeId != null
          ? await _repository.getWatchlistItems(activeId)
          : const <Instrument>[];

      emit(
        WatchlistState(
          isLoading: false,
          watchlists: watchlists,
          selectedWatchlistId: activeId,
          activeItems: items,
          membershipByWatchlist: membership,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _syncSubscription?.cancel();
    return super.close();
  }
}
