import 'package:kiteconnectclient/model/instrument.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Persisted metadata describing the currently indexed instrument master dump.
@immutable
class InstrumentSyncMeta {
  const InstrumentSyncMeta({
    this.lastSyncUtcMs,
    this.etag,
    this.lastModified,
    this.sha256,
    this.rowCount = 0,
    this.verifiedTradingDayIst,
  });

  final int? lastSyncUtcMs;
  final String? etag;
  final String? lastModified;
  final String? sha256;
  final int rowCount;

  /// `YYYY-MM-DD` (in IST) once today's post-08:35 AM IST master dump has been
  /// verified. Remains `null` or yesterday's date for pre-cutoff 08:00 AM syncs!
  final String? verifiedTradingDayIst;

  DateTime? get lastSyncedAtUtc => lastSyncUtcMs != null
      ? DateTime.fromMillisecondsSinceEpoch(lastSyncUtcMs!, isUtc: true)
      : null;
}

/// Local SQLite + FTS5 (with automatic FTS4 fallback) database backing fast,
/// zero-downtime instrument search across 100,000+ Kite instruments.
class InstrumentDatabase {
  InstrumentDatabase._();

  static final InstrumentDatabase instance = InstrumentDatabase._();

  static const String _dbFileName = 'kite_instruments_v1.db';
  static const int _dbVersion = 2;
  static const int _batchChunkSize = 2000;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database {
    if (_db != null) return Future.value(_db!);
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final dbPath = p.join(supportDir.path, _dbFileName);

      final db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onConfigure: (db) async {
          // WAL mode enables concurrent non-blocking reads while 08:35 AM
          // background re-indexing writes inside a transaction.
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA synchronous = NORMAL;');
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
          await _createWatchlistSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createWatchlistSchema(db);
          }
        },
      );
      _db = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS instruments (
        instrument_token INTEGER PRIMARY KEY,
        exchange_token INTEGER NOT NULL,
        tradingsymbol TEXT NOT NULL,
        tradingsymbol_lower TEXT NOT NULL,
        name TEXT NOT NULL,
        last_price REAL NOT NULL,
        expiry TEXT NOT NULL,
        strike REAL NOT NULL,
        tick_size REAL NOT NULL,
        lot_size INTEGER NOT NULL,
        instrument_type TEXT NOT NULL,
        segment TEXT NOT NULL,
        exchange TEXT NOT NULL,
        priority_tier INTEGER NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_instruments_symbol_lower '
      'ON instruments(tradingsymbol_lower);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_instruments_tier_expiry '
      'ON instruments(priority_tier, expiry);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // Prefer FTS5; gracefully fall back to FTS4 on older Android OEM SQLite builds.
    try {
      await db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS instruments_fts '
        "USING fts5(search_tokens, tokenize = 'unicode61');",
      );
    } catch (_) {
      await db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS instruments_fts '
        'USING fts4(search_tokens, tokenize=unicode61);',
      );
    }
  }

  Future<void> _createWatchlistSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS watchlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      );
    ''');

    // Snapshot fields keep watchlist entries intact even while `instruments`
    // is refreshed atomically; queries LEFT JOIN `instruments` for fresh prices.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS watchlist_items (
        watchlist_id INTEGER NOT NULL,
        instrument_token INTEGER NOT NULL,
        exchange_token INTEGER NOT NULL DEFAULT 0,
        tradingsymbol TEXT NOT NULL,
        name TEXT NOT NULL,
        exchange TEXT NOT NULL,
        segment TEXT NOT NULL,
        instrument_type TEXT NOT NULL,
        expiry TEXT NOT NULL,
        strike REAL NOT NULL,
        tick_size REAL NOT NULL,
        lot_size INTEGER NOT NULL,
        last_price REAL NOT NULL,
        priority_tier INTEGER NOT NULL DEFAULT 5,
        sort_order INTEGER NOT NULL DEFAULT 0,
        added_at_ms INTEGER NOT NULL,
        PRIMARY KEY (watchlist_id, instrument_token),
        FOREIGN KEY (watchlist_id) REFERENCES watchlists(id) ON DELETE CASCADE
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_watchlist_items_order '
      'ON watchlist_items(watchlist_id, sort_order, added_at_ms);',
    );
  }

  Future<InstrumentSyncMeta> readSyncMeta() async {
    final db = await database;
    final rows = await db.query('sync_meta');
    final map = <String, String>{
      for (final r in rows)
        if (r['key'] is String && r['value'] is String)
          r['key']! as String: r['value']! as String,
    };

    int count = int.tryParse(map['row_count'] ?? '') ?? 0;
    if (count == 0) {
      final actual = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM instruments'),
      );
      count = actual ?? 0;
    }

    return InstrumentSyncMeta(
      lastSyncUtcMs: int.tryParse(map['last_sync_utc_ms'] ?? ''),
      etag: _nonEmpty(map['etag']),
      lastModified: _nonEmpty(map['last_modified']),
      sha256: _nonEmpty(map['sha256']),
      rowCount: count,
      verifiedTradingDayIst: _nonEmpty(map['verified_trading_day_ist']),
    );
  }

  Future<void> updateSyncMeta({
    int? lastSyncUtcMs,
    String? etag,
    String? lastModified,
    String? sha256,
    int? rowCount,
    String? verifiedTradingDayIst,
    bool clearVerifiedTradingDay = false,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await _writeMetaEntries(
        txn,
        lastSyncUtcMs: lastSyncUtcMs,
        etag: etag,
        lastModified: lastModified,
        sha256: sha256,
        rowCount: rowCount,
        verifiedTradingDayIst: verifiedTradingDayIst,
        clearVerifiedTradingDay: clearVerifiedTradingDay,
      );
    });
  }

  /// Atomically replaces all indexed instruments + FTS entries inside a single
  /// WAL transaction. Readers continue querying the previous snapshot until
  /// commit completes, preventing empty or partial search results mid-sync.
  Future<void> replaceAllInstruments({
    required List<ParsedInstrumentRow> rows,
    required int syncUtcMs,
    required String sha256,
    String? etag,
    String? lastModified,
    String? verifiedTradingDayIst,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('instruments');
      await txn.delete('instruments_fts');

      for (int offset = 0; offset < rows.length; offset += _batchChunkSize) {
        final int end = (offset + _batchChunkSize < rows.length)
            ? offset + _batchChunkSize
            : rows.length;
        final batch = txn.batch();

        for (int i = offset; i < end; i++) {
          final parsed = rows[i];
          final inst = parsed.instrument;

          batch.rawInsert(
            'INSERT OR REPLACE INTO instruments ('
            'instrument_token, exchange_token, tradingsymbol, '
            'tradingsymbol_lower, name, last_price, expiry, strike, '
            'tick_size, lot_size, instrument_type, segment, exchange, '
            'priority_tier'
            ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              inst.instrumentToken,
              inst.exchangeToken,
              inst.tradingsymbol,
              parsed.tradingsymbolLower,
              inst.name,
              inst.lastPrice,
              inst.expiry,
              inst.strike,
              inst.tickSize,
              inst.lotSize,
              inst.instrumentType,
              inst.segment,
              inst.exchange,
              inst.priorityTier,
            ],
          );

          batch.rawInsert(
            'INSERT INTO instruments_fts(rowid, search_tokens) VALUES (?, ?)',
            [inst.instrumentToken, parsed.searchTokens],
          );
        }

        await batch.commit(noResult: true);
      }

      await _writeMetaEntries(
        txn,
        lastSyncUtcMs: syncUtcMs,
        etag: etag,
        lastModified: lastModified,
        sha256: sha256,
        rowCount: rows.length,
        verifiedTradingDayIst: verifiedTradingDayIst,
        clearVerifiedTradingDay: verifiedTradingDayIst == null,
      );
    });
  }

  /// Queries indexed instruments with multi-token FTS prefix matching,
  /// expired-contract filtering (`expiry >= todayIst`), segment filtering,
  /// and financial relevance ranking.
  Future<List<Instrument>> searchInstruments({
    required String query,
    InstrumentSegmentFilter filter = InstrumentSegmentFilter.all,
    int limit = 60,
  }) async {
    final db = await database;
    final String todayIst = _todayIstIsoDate();
    final (String segmentSql, List<Object?> segmentArgs) = _segmentClause(
      filter,
    );

    final List<String> tokens = _tokenizeQuery(query);
    if (tokens.isEmpty) {
      return _defaultSuggestions(
        db: db,
        todayIst: todayIst,
        filter: filter,
        segmentSql: segmentSql,
        segmentArgs: segmentArgs,
        limit: limit,
      );
    }

    // All tokens are strictly lowercase [a-z0-9]+ so SQLite FTS never mistakes
    // words like "or", "and", or "not" for uppercase boolean operators.
    final String ftsMatch = tokens.map((t) => '$t*').join(' ');
    final String normalizedSymbol = query
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
    final String primaryPrefix = '${tokens.first}%';

    final rows = await db.rawQuery(
      '''
      SELECT i.*
      FROM instruments_fts f
      JOIN instruments i ON i.instrument_token = f.rowid
      WHERE instruments_fts MATCH ?
        AND (i.expiry = '' OR i.expiry >= ?)
        $segmentSql
      ORDER BY
        CASE
          WHEN i.tradingsymbol_lower = ? THEN 0
          WHEN i.tradingsymbol_lower LIKE ? THEN 1
          ELSE 2
        END ASC,
        i.priority_tier ASC,
        CASE WHEN i.expiry = '' THEN '9999-99-99' ELSE i.expiry END ASC,
        LENGTH(i.tradingsymbol) ASC
      LIMIT ?
      ''',
      [
        ftsMatch,
        todayIst,
        ...segmentArgs,
        normalizedSymbol,
        primaryPrefix,
        limit,
      ],
    );

    return rows.map(Instrument.fromDbMap).toList(growable: false);
  }

  Future<List<Instrument>> _defaultSuggestions({
    required Database db,
    required String todayIst,
    required InstrumentSegmentFilter filter,
    required String segmentSql,
    required List<Object?> segmentArgs,
    required int limit,
  }) async {
    if (filter == InstrumentSegmentFilter.all) {
      const featuredSymbols = [
        'nifty 50',
        'nifty bank',
        'sensex',
        'india vix',
        'reliance',
        'hdfcbank',
        'tcs',
        'infy',
        'icicibank',
        'sbin',
        'bhartiartl',
        'itc',
        'lt',
        'tatamotors',
      ];
      final placeholders = List.filled(featuredSymbols.length, '?').join(', ');
      final rows = await db.rawQuery(
        '''
        SELECT i.*
        FROM instruments i
        WHERE i.tradingsymbol_lower IN ($placeholders)
          AND (i.segment = 'INDICES' OR (i.exchange = 'NSE' AND i.instrument_type = 'EQ') OR (i.exchange = 'BSE' AND i.segment = 'INDICES'))
        ORDER BY i.priority_tier ASC, i.tradingsymbol ASC
        LIMIT ?
        ''',
        [...featuredSymbols, limit],
      );
      if (rows.isNotEmpty) {
        return rows.map(Instrument.fromDbMap).toList(growable: false);
      }
    }

    final rows = await db.rawQuery(
      '''
      SELECT i.*
      FROM instruments i
      WHERE (i.expiry = '' OR i.expiry >= ?)
        $segmentSql
      ORDER BY
        i.priority_tier ASC,
        CASE WHEN i.expiry = '' THEN '9999-99-99' ELSE i.expiry END ASC,
        i.tradingsymbol ASC
      LIMIT ?
      ''',
      [todayIst, ...segmentArgs, limit],
    );
    return rows.map(Instrument.fromDbMap).toList(growable: false);
  }

  (String, List<Object?>) _segmentClause(InstrumentSegmentFilter filter) {
    return switch (filter) {
      InstrumentSegmentFilter.all => ('', const []),
      InstrumentSegmentFilter.equity => (
        "AND i.instrument_type = 'EQ' AND i.exchange IN ('NSE', 'BSE')",
        const [],
      ),
      InstrumentSegmentFilter.fno => (
        "AND i.exchange IN ('NFO', 'BFO')",
        const [],
      ),
      InstrumentSegmentFilter.indices => ("AND i.segment = 'INDICES'", const []),
      InstrumentSegmentFilter.currency => (
        "AND i.exchange IN ('CDS', 'BCD')",
        const [],
      ),
      InstrumentSegmentFilter.commodities => ("AND i.exchange = 'MCX'", const []),
    };
  }

  List<String> _tokenizeQuery(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return const [];

    // Preserve '&' symbols like "m&m" -> "mm" when adjacent, otherwise split
    // into clean lowercase alphanumeric tokens for FTS prefix matching.
    final normalized = lower.replaceAll('&', '');
    final matches = RegExp(r'[a-z0-9]+').allMatches(normalized);
    return [
      for (final m in matches)
        if (m.group(0)!.isNotEmpty) m.group(0)!,
    ];
  }

  Future<void> _writeMetaEntries(
    DatabaseExecutor txn, {
    int? lastSyncUtcMs,
    String? etag,
    String? lastModified,
    String? sha256,
    int? rowCount,
    String? verifiedTradingDayIst,
    bool clearVerifiedTradingDay = false,
  }) async {
    Future<void> put(String key, String value) => txn.insert(
      'sync_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (lastSyncUtcMs != null) {
      await put('last_sync_utc_ms', lastSyncUtcMs.toString());
    }
    if (etag != null && etag.isNotEmpty) {
      await put('etag', etag);
    }
    if (lastModified != null && lastModified.isNotEmpty) {
      await put('last_modified', lastModified);
    }
    if (sha256 != null && sha256.isNotEmpty) {
      await put('sha256', sha256);
    }
    if (rowCount != null) {
      await put('row_count', rowCount.toString());
    }
    if (clearVerifiedTradingDay) {
      await txn.delete(
        'sync_meta',
        where: 'key = ?',
        whereArgs: const ['verified_trading_day_ist'],
      );
    } else if (verifiedTradingDayIst != null &&
        verifiedTradingDayIst.isNotEmpty) {
      await put('verified_trading_day_ist', verifiedTradingDayIst);
    }
  }

  static String _todayIstIsoDate() {
    final ist = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final y = ist.year.toString().padLeft(4, '0');
    final m = ist.month.toString().padLeft(2, '0');
    final d = ist.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String? _nonEmpty(String? v) =>
      (v == null || v.isEmpty) ? null : v;
}
