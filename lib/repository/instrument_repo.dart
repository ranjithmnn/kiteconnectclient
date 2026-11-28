import 'package:kiteconnectclient/constants/endpoints.dart';
import 'package:kiteconnectclient/model/instrument.dart';
import 'package:kiteconnectclient/services/local/instrument_db.dart';
import 'package:kiteconnectclient/services/remote/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Coordinates remote `/instruments` CSV downloads and local SQLite FTS queries.
class InstrumentRepository {
  InstrumentRepository({
    DioClient? dioClient,
    InstrumentDatabase? database,
  }) : _dioClient = dioClient ?? DioClient.instance,
       _database = database ?? InstrumentDatabase.instance;

  final DioClient _dioClient;
  final InstrumentDatabase _database;

  Future<InstrumentSyncMeta> getSyncMeta() => _database.readSyncMeta();

  Future<String> temporaryDownloadPath() async {
    final tempDir = await getTemporaryDirectory();
    return p.join(tempDir.path, 'kite_instruments_download.csv.part');
  }

  Future<DownloadResult> downloadInstrumentsToFile({
    required String savePath,
    String? ifNoneMatch,
    String? ifModifiedSince,
    void Function(int received, int total)? onProgress,
  }) {
    return _dioClient.downloadToFile(
      Endpoints.instruments,
      savePath: savePath,
      ifNoneMatch: ifNoneMatch,
      ifModifiedSince: ifModifiedSince,
      onProgress: onProgress,
    );
  }

  Future<void> saveParsedInstruments({
    required List<ParsedInstrumentRow> rows,
    required int syncUtcMs,
    required String sha256,
    String? etag,
    String? lastModified,
    String? verifiedTradingDayIst,
  }) {
    return _database.replaceAllInstruments(
      rows: rows,
      syncUtcMs: syncUtcMs,
      sha256: sha256,
      etag: etag,
      lastModified: lastModified,
      verifiedTradingDayIst: verifiedTradingDayIst,
    );
  }

  Future<void> markSyncVerified({
    required int syncUtcMs,
    String? etag,
    String? lastModified,
    String? verifiedTradingDayIst,
  }) {
    return _database.updateSyncMeta(
      lastSyncUtcMs: syncUtcMs,
      etag: etag,
      lastModified: lastModified,
      verifiedTradingDayIst: verifiedTradingDayIst,
    );
  }

  Future<List<Instrument>> search({
    required String query,
    InstrumentSegmentFilter filter = InstrumentSegmentFilter.all,
    int limit = 60,
  }) {
    return _database.searchInstruments(
      query: query,
      filter: filter,
      limit: limit,
    );
  }
}
