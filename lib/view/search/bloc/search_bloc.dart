import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/model/instrument.dart';
import 'package:kiteconnectclient/repository/instrument_repo.dart';
import 'package:kiteconnectclient/services/instrument_sync_service.dart';
import 'package:meta/meta.dart';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    InstrumentRepository? repository,
    InstrumentSyncService? syncService,
  }) : _repository = repository ?? InstrumentRepository(),
       _syncService = syncService ?? InstrumentSyncService.instance,
       super(
         SearchState(
           syncStatus: (syncService ?? InstrumentSyncService.instance).status,
         ),
       ) {
    on<SearchStarted>(_onStarted);
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchFilterChanged>(_onFilterChanged);
    on<SearchRetrySyncRequested>(_onRetrySyncRequested);
    on<_SearchExecuteDebounced>(_onExecuteDebounced);
    on<_SearchSyncStatusChanged>(_onSyncStatusChanged);

    _syncSubscription = _syncService.statusStream.listen((status) {
      add(_SearchSyncStatusChanged(status));
    });
  }

  static const Duration _debounceDuration = Duration(milliseconds: 90);

  final InstrumentRepository _repository;
  final InstrumentSyncService _syncService;
  StreamSubscription<InstrumentSyncStatus>? _syncSubscription;
  Timer? _debounceTimer;
  int _searchGeneration = 0;

  Future<void> _onStarted(
    SearchStarted event,
    Emitter<SearchState> emit,
  ) async {
    // Load any cached SQLite meta/results immediately without waiting on network.
    final meta = await _repository.getSyncMeta();
    if (meta.rowCount > 0 && !state.syncStatus.hasInstruments) {
      emit(
        state.copyWith(
          syncStatus: state.syncStatus.copyWith(
            phase: state.syncStatus.isSyncing
                ? state.syncStatus.phase
                : InstrumentSyncPhase.ready,
            indexedCount: meta.rowCount,
            lastSyncedAtUtc: meta.lastSyncedAtUtc,
          ),
        ),
      );
    }

    if (meta.rowCount > 0 || state.syncStatus.hasInstruments) {
      await _runQuery(emit);
    }

    // Trigger non-blocking sync check (recovers from offline launch if needed).
    unawaited(_syncService.ensureSynced());
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    _debounceTimer?.cancel();
    emit(state.copyWith(query: event.query));

    if (!state.syncStatus.hasInstruments) {
      return;
    }

    // Clear query updates immediately; non-empty typing is debounced (90ms).
    if (event.query.trim().isEmpty) {
      await _runQuery(emit);
      return;
    }

    _debounceTimer = Timer(_debounceDuration, () {
      if (!isClosed) {
        add(const _SearchExecuteDebounced());
      }
    });
  }

  Future<void> _onFilterChanged(
    SearchFilterChanged event,
    Emitter<SearchState> emit,
  ) async {
    if (event.filter == state.filter) return;
    _debounceTimer?.cancel();
    emit(state.copyWith(filter: event.filter));
    if (state.syncStatus.hasInstruments) {
      await _runQuery(emit);
    }
  }

  Future<void> _onExecuteDebounced(
    _SearchExecuteDebounced event,
    Emitter<SearchState> emit,
  ) async {
    if (state.syncStatus.hasInstruments) {
      await _runQuery(emit);
    }
  }

  Future<void> _onRetrySyncRequested(
    SearchRetrySyncRequested event,
    Emitter<SearchState> emit,
  ) async {
    unawaited(_syncService.ensureSynced(force: event.force));
  }

  Future<void> _onSyncStatusChanged(
    _SearchSyncStatusChanged event,
    Emitter<SearchState> emit,
  ) async {
    final prevCount = state.syncStatus.indexedCount;
    final prevPhase = state.syncStatus.phase;
    emit(state.copyWith(syncStatus: event.status));

    // Automatically execute or refresh the active search query when:
    // 1) Initial empty DB finishes indexing, OR
    // 2) 08:35 AM IST background hot-swap finishes committing new rows!
    final bool becameReady =
        event.status.hasInstruments &&
        (prevCount == 0 ||
            (prevPhase != InstrumentSyncPhase.ready &&
                event.status.phase == InstrumentSyncPhase.ready));

    if (becameReady) {
      await _runQuery(emit);
    }
  }

  Future<void> _runQuery(Emitter<SearchState> emit) async {
    final int gen = ++_searchGeneration;
    emit(state.copyWith(isSearching: true));
    try {
      final matches = await _repository.search(
        query: state.query,
        filter: state.filter,
      );
      if (gen != _searchGeneration) return;
      emit(state.copyWith(results: matches, isSearching: false));
    } catch (_) {
      if (gen != _searchGeneration) return;
      emit(state.copyWith(isSearching: false));
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _syncSubscription?.cancel();
    return super.close();
  }
}
