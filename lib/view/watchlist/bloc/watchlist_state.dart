part of 'watchlist_bloc.dart';

@immutable
final class WatchlistState {
  const WatchlistState({
    this.isLoading = true,
    this.watchlists = const [],
    this.selectedWatchlistId,
    this.activeItems = const [],
    this.membershipByWatchlist = const {},
    this.errorMessage,
  });

  final bool isLoading;
  final List<Watchlist> watchlists;
  final int? selectedWatchlistId;
  final List<Instrument> activeItems;

  /// Lookup map `watchlistId -> Set<instrumentToken>` for instant O(1) checks.
  final Map<int, Set<int>> membershipByWatchlist;
  final String? errorMessage;

  Watchlist? get selectedWatchlist {
    final id = selectedWatchlistId;
    if (id == null) return watchlists.isNotEmpty ? watchlists.first : null;
    for (final w in watchlists) {
      if (w.id == id) return w;
    }
    return watchlists.isNotEmpty ? watchlists.first : null;
  }

  bool isInWatchlist(int watchlistId, int instrumentToken) {
    return membershipByWatchlist[watchlistId]?.contains(instrumentToken) ??
        false;
  }

  int watchlistCountFor(int instrumentToken) {
    int count = 0;
    for (final tokens in membershipByWatchlist.values) {
      if (tokens.contains(instrumentToken)) count++;
    }
    return count;
  }

  WatchlistState copyWith({
    bool? isLoading,
    List<Watchlist>? watchlists,
    int? selectedWatchlistId,
    List<Instrument>? activeItems,
    Map<int, Set<int>>? membershipByWatchlist,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WatchlistState(
      isLoading: isLoading ?? this.isLoading,
      watchlists: watchlists ?? this.watchlists,
      selectedWatchlistId: selectedWatchlistId ?? this.selectedWatchlistId,
      activeItems: activeItems ?? this.activeItems,
      membershipByWatchlist:
          membershipByWatchlist ?? this.membershipByWatchlist,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
