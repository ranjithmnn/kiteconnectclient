part of 'search_bloc.dart';

@immutable
final class SearchState {
  const SearchState({
    this.query = '',
    this.filter = InstrumentSegmentFilter.all,
    this.results = const [],
    this.isSearching = false,
    this.syncStatus = const InstrumentSyncStatus(),
  });

  final String query;
  final InstrumentSegmentFilter filter;
  final List<Instrument> results;
  final bool isSearching;
  final InstrumentSyncStatus syncStatus;

  SearchState copyWith({
    String? query,
    InstrumentSegmentFilter? filter,
    List<Instrument>? results,
    bool? isSearching,
    InstrumentSyncStatus? syncStatus,
  }) {
    return SearchState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
