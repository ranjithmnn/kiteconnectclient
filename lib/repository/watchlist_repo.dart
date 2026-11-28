import 'package:kiteconnectclient/model/instrument.dart';
import 'package:kiteconnectclient/model/watchlist.dart';
import 'package:kiteconnectclient/services/local/instrument_db.dart';
import 'package:sqflite/sqflite.dart';

/// Persists user watchlists and their saved instruments in SQLite, joining
/// against the indexed `instruments` master table for latest snapshot prices.
class WatchlistRepository {
  WatchlistRepository({InstrumentDatabase? database})
    : _database = database ?? InstrumentDatabase.instance;

  final InstrumentDatabase _database;

  /// Loads all watchlists ordered by `sort_order`, seeding a default
  /// `"Watchlist 1"` on first launch when none exist yet.
  Future<List<Watchlist>> getWatchlists() async {
    final db = await _database.database;
    var rows = await _queryWatchlistsWithCount(db);

    if (rows.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('watchlists', {
        'name': 'Watchlist 1',
        'sort_order': 0,
        'created_at_ms': now,
      });
      rows = await _queryWatchlistsWithCount(db);
    }

    return rows.map(Watchlist.fromDbMap).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> _queryWatchlistsWithCount(Database db) {
    return db.rawQuery('''
      SELECT
        w.id,
        w.name,
        w.sort_order,
        w.created_at_ms,
        COUNT(wi.instrument_token) AS item_count
      FROM watchlists w
      LEFT JOIN watchlist_items wi ON wi.watchlist_id = w.id
      GROUP BY w.id
      ORDER BY w.sort_order ASC, w.id ASC
    ''');
  }

  Future<Watchlist> createWatchlist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Watchlist name cannot be empty.');
    }

    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxOrder =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) FROM watchlists'),
        ) ??
        -1;
    final nextOrder = maxOrder + 1;

    final id = await db.insert('watchlists', {
      'name': trimmed,
      'sort_order': nextOrder,
      'created_at_ms': now,
    });

    return Watchlist(
      id: id,
      name: trimmed,
      sortOrder: nextOrder,
      createdAtMs: now,
    );
  }

  Future<void> renameWatchlist({
    required int watchlistId,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final db = await _database.database;
    await db.update(
      'watchlists',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [watchlistId],
    );
  }

  Future<void> deleteWatchlist(int watchlistId) async {
    final db = await _database.database;
    await db.delete(
      'watchlists',
      where: 'id = ?',
      whereArgs: [watchlistId],
    );
  }

  /// Returns the ordered instruments in [watchlistId], enriched with live
  /// master attributes (`last_price`, `lot_size`, etc.) when present in the
  /// indexed `instruments` table.
  Future<List<Instrument>> getWatchlistItems(int watchlistId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        wi.instrument_token,
        COALESCE(i.exchange_token, wi.exchange_token) AS exchange_token,
        COALESCE(i.tradingsymbol, wi.tradingsymbol) AS tradingsymbol,
        COALESCE(i.name, wi.name) AS name,
        COALESCE(i.last_price, wi.last_price) AS last_price,
        COALESCE(i.expiry, wi.expiry) AS expiry,
        COALESCE(i.strike, wi.strike) AS strike,
        COALESCE(i.tick_size, wi.tick_size) AS tick_size,
        COALESCE(i.lot_size, wi.lot_size) AS lot_size,
        COALESCE(i.instrument_type, wi.instrument_type) AS instrument_type,
        COALESCE(i.segment, wi.segment) AS segment,
        COALESCE(i.exchange, wi.exchange) AS exchange,
        COALESCE(i.priority_tier, wi.priority_tier) AS priority_tier
      FROM watchlist_items wi
      LEFT JOIN instruments i ON i.instrument_token = wi.instrument_token
      WHERE wi.watchlist_id = ?
      ORDER BY wi.sort_order ASC, wi.added_at_ms ASC
      ''',
      [watchlistId],
    );

    return rows.map(Instrument.fromDbMap).toList(growable: false);
  }

  /// Returns a lookup map of `watchlistId -> Set<instrumentToken>` so Search
  /// and Watchlist views can check membership in `O(1)`.
  Future<Map<int, Set<int>>> getMembershipByWatchlist() async {
    final db = await _database.database;
    final rows = await db.query(
      'watchlist_items',
      columns: ['watchlist_id', 'instrument_token'],
    );
    final result = <int, Set<int>>{};
    for (final row in rows) {
      final wId = (row['watchlist_id'] as num).toInt();
      final token = (row['instrument_token'] as num).toInt();
      (result[wId] ??= <int>{}).add(token);
    }
    return result;
  }

  Future<void> addInstrument({
    required int watchlistId,
    required Instrument instrument,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxOrder =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(MAX(sort_order), -1) FROM watchlist_items WHERE watchlist_id = ?',
            [watchlistId],
          ),
        ) ??
        -1;

    await db.insert(
      'watchlist_items',
      {
        'watchlist_id': watchlistId,
        'instrument_token': instrument.instrumentToken,
        'exchange_token': instrument.exchangeToken,
        'tradingsymbol': instrument.tradingsymbol,
        'name': instrument.name,
        'exchange': instrument.exchange,
        'segment': instrument.segment,
        'instrument_type': instrument.instrumentType,
        'expiry': instrument.expiry,
        'strike': instrument.strike,
        'tick_size': instrument.tickSize,
        'lot_size': instrument.lotSize,
        'last_price': instrument.lastPrice,
        'priority_tier': instrument.priorityTier,
        'sort_order': maxOrder + 1,
        'added_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeInstrument({
    required int watchlistId,
    required int instrumentToken,
  }) async {
    final db = await _database.database;
    await db.delete(
      'watchlist_items',
      where: 'watchlist_id = ? AND instrument_token = ?',
      whereArgs: [watchlistId, instrumentToken],
    );
  }

  Future<void> reorderWatchlistItems({
    required int watchlistId,
    required List<int> orderedTokens,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (int i = 0; i < orderedTokens.length; i++) {
        batch.update(
          'watchlist_items',
          {'sort_order': i},
          where: 'watchlist_id = ? AND instrument_token = ?',
          whereArgs: [watchlistId, orderedTokens[i]],
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
