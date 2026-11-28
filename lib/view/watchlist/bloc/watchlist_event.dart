part of 'watchlist_bloc.dart';

sealed class WatchlistEvent {
  const WatchlistEvent();
}

final class WatchlistStarted extends WatchlistEvent {
  const WatchlistStarted();
}

final class WatchlistSelected extends WatchlistEvent {
  const WatchlistSelected(this.watchlistId);
  final int watchlistId;
}

final class WatchlistCreated extends WatchlistEvent {
  const WatchlistCreated({
    required this.name,
    this.initialInstrument,
    this.selectAfterCreate = true,
  });

  final String name;
  final Instrument? initialInstrument;
  final bool selectAfterCreate;
}

final class WatchlistRenamed extends WatchlistEvent {
  const WatchlistRenamed({
    required this.watchlistId,
    required this.newName,
  });

  final int watchlistId;
  final String newName;
}

final class WatchlistDeleted extends WatchlistEvent {
  const WatchlistDeleted(this.watchlistId);
  final int watchlistId;
}

final class WatchlistInstrumentToggled extends WatchlistEvent {
  const WatchlistInstrumentToggled({
    required this.watchlistId,
    required this.instrument,
  });

  final int watchlistId;
  final Instrument instrument;
}

final class WatchlistInstrumentRemoved extends WatchlistEvent {
  const WatchlistInstrumentRemoved({
    required this.watchlistId,
    required this.instrumentToken,
  });

  final int watchlistId;
  final int instrumentToken;
}

final class WatchlistRefreshed extends WatchlistEvent {
  const WatchlistRefreshed();
}
