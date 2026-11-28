import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kiteconnectclient/model/instrument.dart';
import 'package:kiteconnectclient/repository/instrument_repo.dart';
import 'package:kiteconnectclient/services/remote/dio.dart';

enum InstrumentSyncPhase { idle, downloading, indexing, ready, error }

@immutable
class InstrumentSyncStatus {
  const InstrumentSyncStatus({
    this.phase = InstrumentSyncPhase.idle,
    this.indexedCount = 0,
    this.lastSyncedAtUtc,
    this.isProvisionalPreCutoff = false,
    this.downloadProgress,
    this.errorMessage,
  });

  final InstrumentSyncPhase phase;
  final int indexedCount;
  final DateTime? lastSyncedAtUtc;

  /// `true` when operating before `08:35 AM IST` on yesterday's or pre-cutoff
  /// master dump; an automatic timer will refresh once `08:35 AM IST` arrives.
  final bool isProvisionalPreCutoff;

  /// Download progress fraction (`0.0–1.0`) when `Content-Length` is known.
  final double? downloadProgress;

  final String? errorMessage;

  bool get isSyncing =>
      phase == InstrumentSyncPhase.downloading ||
      phase == InstrumentSyncPhase.indexing;

  bool get hasInstruments => indexedCount > 0;

  InstrumentSyncStatus copyWith({
    InstrumentSyncPhase? phase,
    int? indexedCount,
    DateTime? lastSyncedAtUtc,
    bool? isProvisionalPreCutoff,
    double? downloadProgress,
    bool clearDownloadProgress = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InstrumentSyncStatus(
      phase: phase ?? this.phase,
      indexedCount: indexedCount ?? this.indexedCount,
      lastSyncedAtUtc: lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      isProvisionalPreCutoff:
          isProvisionalPreCutoff ?? this.isProvisionalPreCutoff,
      downloadProgress: clearDownloadProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Manages the daily Kite Connect `/instruments` CSV lifecycle across:
/// - Cold launch & post-login background sync
/// - `08:00 AM IST` provisional sessions -> automatic `08:35 AM IST` upgrade timer
/// - Weekday `08:35–09:25 AM IST` delayed-dump backoff retries (`ETag` / `SHA-256`)
/// - `AppLifecycleState.resumed` foreground checks
/// - Single-flight deduplication so parallel callers never collide
class InstrumentSyncService with WidgetsBindingObserver {
  InstrumentSyncService._({
    InstrumentRepository? repository,
    FlutterSecureStorage? storage,
  }) : _repository = repository ?? InstrumentRepository(),
       _storage = storage ?? const FlutterSecureStorage();

  static final InstrumentSyncService instance = InstrumentSyncService._();

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);
  static const int _cutoffHourIst = 8;
  static const int _cutoffMinuteIst = 35;
  static const int _lateRetryWindowEndHourIst = 9;
  static const int _lateRetryWindowEndMinuteIst = 25;
  static const List<Duration> _delayedMasterBackoff = [
    Duration(minutes: 5),
    Duration(minutes: 8),
    Duration(minutes: 12),
  ];

  final InstrumentRepository _repository;
  final FlutterSecureStorage _storage;

  final ValueNotifier<InstrumentSyncStatus> _status = ValueNotifier(
    const InstrumentSyncStatus(),
  );
  final StreamController<InstrumentSyncStatus> _statusController =
      StreamController<InstrumentSyncStatus>.broadcast();

  ValueListenable<InstrumentSyncStatus> get statusListenable => _status;
  InstrumentSyncStatus get status => _status.value;
  Stream<InstrumentSyncStatus> get statusStream => _statusController.stream;

  bool _initialized = false;
  Completer<void>? _inFlightSync;
  Timer? _cutoffTimer;
  Timer? _retryTimer;
  int _delayedMasterAttempt = 0;

  /// Attaches app lifecycle observer, loads cached SQLite metadata immediately,
  /// and triggers a non-blocking sync check.
  Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
    }

    try {
      final meta = await _repository.getSyncMeta();
      if (meta.rowCount > 0) {
        final nowIst = _nowIst();
        final todayStr = _formatDate(nowIst);
        final afterCutoff = !_isBeforeCutoff(nowIst);
        _emit(
          InstrumentSyncStatus(
            phase: InstrumentSyncPhase.ready,
            indexedCount: meta.rowCount,
            lastSyncedAtUtc: meta.lastSyncedAtUtc,
            isProvisionalPreCutoff:
                !afterCutoff || meta.verifiedTradingDayIst != todayStr,
          ),
        );
      }
    } catch (e) {
      debugPrint('[InstrumentSync] Initial meta read failed: $e');
    }

    unawaited(ensureSynced());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Catches 08:00 AM -> 09:15 AM phone lock/unlock transitions where
      // OS backgrounding paused Dart timers.
      unawaited(ensureSynced());
    }
  }

  /// Ensures the local SQLite FTS index is populated and up-to-date for the
  /// current IST trading day. Concurrent calls share a single in-flight run.
  Future<void> ensureSynced({bool force = false}) {
    if (_inFlightSync != null) {
      return _inFlightSync!.future;
    }

    final completer = Completer<void>();
    _inFlightSync = completer;

    _runSync(force: force).whenComplete(() {
      _inFlightSync = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }

  Future<void> _runSync({required bool force}) async {
    _retryTimer?.cancel();

    final accessToken = await _storage.read(key: 'access_token');
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    final nowIst = _nowIst();
    final todayStr = _formatDate(nowIst);
    final bool afterCutoff = !_isBeforeCutoff(nowIst);

    // If it's before 08:35 AM IST (e.g. 08:00 AM IST), always arm the timer
    // so an active foreground session refreshes automatically at 08:35 AM IST!
    if (!afterCutoff) {
      _scheduleTodayCutoffTimer(nowIst);
    } else {
      _cutoffTimer?.cancel();
    }

    final meta = await _repository.getSyncMeta();

    if (!force) {
      if (afterCutoff &&
          meta.rowCount > 0 &&
          meta.verifiedTradingDayIst == todayStr) {
        _delayedMasterAttempt = 0;
        _emit(
          InstrumentSyncStatus(
            phase: InstrumentSyncPhase.ready,
            indexedCount: meta.rowCount,
            lastSyncedAtUtc: meta.lastSyncedAtUtc,
            isProvisionalPreCutoff: false,
          ),
        );
        return;
      }

      // Before 08:35 AM IST (e.g. 08:00 AM): if we already have a recent
      // index (< 20 hours old), serve it immediately without wasting bandwidth,
      // and wait for the 08:35 AM IST cutoff timer to pull today's new dump.
      if (!afterCutoff && meta.rowCount > 0 && meta.lastSyncedAtUtc != null) {
        final age = DateTime.now().toUtc().difference(meta.lastSyncedAtUtc!);
        if (age < const Duration(hours: 20)) {
          _emit(
            InstrumentSyncStatus(
              phase: InstrumentSyncPhase.ready,
              indexedCount: meta.rowCount,
              lastSyncedAtUtc: meta.lastSyncedAtUtc,
              isProvisionalPreCutoff: true,
            ),
          );
          return;
        }
      }
    }

    final String tempPath = await _repository.temporaryDownloadPath();
    final bool hasCachedData = meta.rowCount > 0;

    _emit(
      _status.value.copyWith(
        phase: InstrumentSyncPhase.downloading,
        indexedCount: meta.rowCount,
        clearDownloadProgress: true,
        clearError: true,
      ),
    );

    try {
      final download = await _repository.downloadInstrumentsToFile(
        savePath: tempPath,
        ifNoneMatch: (!force && hasCachedData) ? meta.etag : null,
        ifModifiedSince: (!force && hasCachedData) ? meta.lastModified : null,
        onProgress: (received, total) {
          if (total > 0) {
            _emit(
              _status.value.copyWith(
                downloadProgress: (received / total).clamp(0.0, 1.0),
              ),
            );
          }
        },
      );

      final int syncUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final String? effectiveLastMod =
          download.lastModified ?? meta.lastModified;
      final String? effectiveEtag = download.etag ?? meta.etag;

      if (download.notModified && hasCachedData) {
        await _handleUnchangedMaster(
          nowIst: nowIst,
          todayStr: todayStr,
          afterCutoff: afterCutoff,
          syncUtcMs: syncUtcMs,
          rowCount: meta.rowCount,
          etag: effectiveEtag,
          lastModified: effectiveLastMod,
        );
        return;
      }

      _emit(
        _status.value.copyWith(
          phase: InstrumentSyncPhase.indexing,
          clearDownloadProgress: true,
        ),
      );

      final parsed = await parseInstrumentsFileInIsolate(
        filePath: tempPath,
        previousSha256: (!force && hasCachedData) ? meta.sha256 : null,
      );

      if (parsed.unchanged && hasCachedData) {
        await _handleUnchangedMaster(
          nowIst: nowIst,
          todayStr: todayStr,
          afterCutoff: afterCutoff,
          syncUtcMs: syncUtcMs,
          rowCount: meta.rowCount,
          etag: effectiveEtag,
          lastModified: effectiveLastMod,
        );
        return;
      }

      // Fresh CSV payload! Only stamp `verifiedTradingDayIst = todayStr` if
      // we are at/after the 08:35 AM IST cutoff. Pre-cutoff 08:00 AM downloads
      // remain provisional so the 08:35 AM IST timer still upgrades them!
      final String? verifiedDay = afterCutoff ? todayStr : null;
      _delayedMasterAttempt = 0;

      await _repository.saveParsedInstruments(
        rows: parsed.rows,
        syncUtcMs: syncUtcMs,
        sha256: parsed.sha256,
        etag: effectiveEtag,
        lastModified: effectiveLastMod,
        verifiedTradingDayIst: verifiedDay,
      );

      _emit(
        InstrumentSyncStatus(
          phase: InstrumentSyncPhase.ready,
          indexedCount: parsed.rows.length,
          lastSyncedAtUtc: DateTime.fromMillisecondsSinceEpoch(
            syncUtcMs,
            isUtc: true,
          ),
          isProvisionalPreCutoff: !afterCutoff,
        ),
      );
    } on ApiException catch (e) {
      debugPrint('[InstrumentSync] API error: ${e.message}');
      _emit(
        _status.value.copyWith(
          phase: hasCachedData
              ? InstrumentSyncPhase.ready
              : InstrumentSyncPhase.error,
          indexedCount: meta.rowCount,
          clearDownloadProgress: true,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      debugPrint('[InstrumentSync] Unexpected error: $e');
      _emit(
        _status.value.copyWith(
          phase: hasCachedData
              ? InstrumentSyncPhase.ready
              : InstrumentSyncPhase.error,
          indexedCount: meta.rowCount,
          clearDownloadProgress: true,
          errorMessage: 'Failed to index instruments. Please retry.',
        ),
      );
    } finally {
      final partFile = File(tempPath);
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _handleUnchangedMaster({
    required DateTime nowIst,
    required String todayStr,
    required bool afterCutoff,
    required int syncUtcMs,
    required int rowCount,
    required String? etag,
    required String? lastModified,
  }) async {
    final bool lastModIsToday = _isHttpDateTodayIst(lastModified, todayStr);
    final bool isWeekday =
        nowIst.weekday >= DateTime.monday && nowIst.weekday <= DateTime.friday;
    final bool inMorningDelayWindow =
        afterCutoff && isWeekday && _isBeforeLateRetryEnd(nowIst);

    // Trap C protection: If it's 08:35–09:25 AM IST on a weekday and the server
    // is STILL returning yesterday's dump (`!lastModIsToday`), do NOT lock out
    // today yet—schedule a bounded backoff retry!
    if (inMorningDelayWindow &&
        !lastModIsToday &&
        _delayedMasterAttempt < _delayedMasterBackoff.length) {
      final delay = _delayedMasterBackoff[_delayedMasterAttempt++];
      debugPrint(
        '[InstrumentSync] Master dump not yet regenerated post-08:35 IST; '
        'scheduling retry #$_delayedMasterAttempt in ${delay.inMinutes}m.',
      );
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () => unawaited(ensureSynced()));

      _emit(
        InstrumentSyncStatus(
          phase: InstrumentSyncPhase.ready,
          indexedCount: rowCount,
          lastSyncedAtUtc: DateTime.fromMillisecondsSinceEpoch(
            syncUtcMs,
            isUtc: true,
          ),
          isProvisionalPreCutoff: true,
        ),
      );
      return;
    }

    _delayedMasterAttempt = 0;
    final String? verifiedDay = afterCutoff ? todayStr : null;
    await _repository.markSyncVerified(
      syncUtcMs: syncUtcMs,
      etag: etag,
      lastModified: lastModified,
      verifiedTradingDayIst: verifiedDay,
    );

    _emit(
      InstrumentSyncStatus(
        phase: InstrumentSyncPhase.ready,
        indexedCount: rowCount,
        lastSyncedAtUtc: DateTime.fromMillisecondsSinceEpoch(
          syncUtcMs,
          isUtc: true,
        ),
        isProvisionalPreCutoff: !afterCutoff,
      ),
    );
  }

  void _scheduleTodayCutoffTimer(DateTime nowIst) {
    _cutoffTimer?.cancel();
    final cutoffIst = DateTime.utc(
      nowIst.year,
      nowIst.month,
      nowIst.day,
      _cutoffHourIst,
      _cutoffMinuteIst,
      5,
    );
    final wait = cutoffIst.difference(nowIst);
    if (wait.isNegative || wait == Duration.zero) {
      return;
    }
    debugPrint(
      '[InstrumentSync] Armed 08:35 AM IST upgrade timer '
      '(fires in ${wait.inMinutes}m ${wait.inSeconds % 60}s).',
    );
    _cutoffTimer = Timer(wait, () => unawaited(ensureSynced()));
  }

  void _emit(InstrumentSyncStatus next) {
    _status.value = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  static DateTime _nowIst() => DateTime.now().toUtc().add(_istOffset);

  static bool _isBeforeCutoff(DateTime ist) {
    if (ist.hour < _cutoffHourIst) return true;
    if (ist.hour > _cutoffHourIst) return false;
    return ist.minute < _cutoffMinuteIst;
  }

  static bool _isBeforeLateRetryEnd(DateTime ist) {
    if (ist.hour < _lateRetryWindowEndHourIst) return true;
    if (ist.hour > _lateRetryWindowEndHourIst) return false;
    return ist.minute <= _lateRetryWindowEndMinuteIst;
  }

  static bool _isHttpDateTodayIst(String? rawHttpDate, String todayIstStr) {
    if (rawHttpDate == null || rawHttpDate.isEmpty) return false;
    try {
      final parsedUtc = HttpDate.parse(rawHttpDate).toUtc();
      final parsedIst = parsedUtc.add(_istOffset);
      return _formatDate(parsedIst) == todayIstStr;
    } catch (_) {
      return false;
    }
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
