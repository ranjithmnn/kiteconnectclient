part of 'search_bloc.dart';

sealed class SearchEvent {
  const SearchEvent();
}

final class SearchStarted extends SearchEvent {
  const SearchStarted();
}

final class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);
  final String query;
}

final class SearchFilterChanged extends SearchEvent {
  const SearchFilterChanged(this.filter);
  final InstrumentSegmentFilter filter;
}

final class SearchRetrySyncRequested extends SearchEvent {
  const SearchRetrySyncRequested({this.force = false});
  final bool force;
}

final class _SearchExecuteDebounced extends SearchEvent {
  const _SearchExecuteDebounced();
}

final class _SearchSyncStatusChanged extends SearchEvent {
  const _SearchSyncStatusChanged(this.status);
  final InstrumentSyncStatus status;
}
