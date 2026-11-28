import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Category filter tabs displayed in [SearchView].
enum InstrumentSegmentFilter {
  all('All'),
  equity('Equity'),
  fno('F&O'),
  indices('Indices'),
  currency('Currency'),
  commodities('MCX');

  const InstrumentSegmentFilter(this.label);
  final String label;
}

/// Represents a single tradable or index instrument from Kite Connect's
/// `/instruments` master dump.
@immutable
class Instrument {
  const Instrument({
    required this.instrumentToken,
    required this.exchangeToken,
    required this.tradingsymbol,
    required this.name,
    required this.lastPrice,
    required this.expiry,
    required this.strike,
    required this.tickSize,
    required this.lotSize,
    required this.instrumentType,
    required this.segment,
    required this.exchange,
    required this.priorityTier,
  });

  final int instrumentToken;
  final int exchangeToken;
  final String tradingsymbol;
  final String name;
  final double lastPrice;
  final String expiry;
  final double strike;
  final double tickSize;
  final int lotSize;
  final String instrumentType;
  final String segment;
  final String exchange;
  final int priorityTier;

  bool get isDerivative => expiry.isNotEmpty || instrumentType != 'EQ';

  /// Human-readable subtitle for search rows (company name for equities,
  /// formatted contract details for derivatives).
  String get displaySubtitle {
    if (segment == 'INDICES') {
      return name.isNotEmpty ? '$name · Index' : 'Market Index';
    }
    if (!isDerivative) {
      return name.isNotEmpty ? name : exchange;
    }

    final parts = <String>[];
    if (expiry.length >= 10) {
      parts.add(_formatExpiryPretty(expiry));
    }
    if (strike > 0) {
      final strikeText = strike == strike.truncateToDouble()
          ? strike.toInt().toString()
          : strike.toStringAsFixed(2);
      parts.add('$strikeText $instrumentType');
    } else if (instrumentType.isNotEmpty) {
      parts.add(instrumentType);
    }
    if (lotSize > 1) {
      parts.add('Lot $lotSize');
    }
    if (parts.isEmpty && name.isNotEmpty) {
      return name;
    }
    return parts.join(' · ');
  }

  factory Instrument.fromDbMap(Map<String, Object?> map) {
    return Instrument(
      instrumentToken: (map['instrument_token'] as num).toInt(),
      exchangeToken: (map['exchange_token'] as num?)?.toInt() ?? 0,
      tradingsymbol: (map['tradingsymbol'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      lastPrice: (map['last_price'] as num?)?.toDouble() ?? 0.0,
      expiry: (map['expiry'] as String?) ?? '',
      strike: (map['strike'] as num?)?.toDouble() ?? 0.0,
      tickSize: (map['tick_size'] as num?)?.toDouble() ?? 0.05,
      lotSize: (map['lot_size'] as num?)?.toInt() ?? 1,
      instrumentType: (map['instrument_type'] as String?) ?? '',
      segment: (map['segment'] as String?) ?? '',
      exchange: (map['exchange'] as String?) ?? '',
      priorityTier: (map['priority_tier'] as num?)?.toInt() ?? 5,
    );
  }

  static String _formatExpiryPretty(String isoDate) {
    if (isoDate.length < 10) return isoDate;
    final year = isoDate.substring(2, 4);
    final month = int.tryParse(isoDate.substring(5, 7)) ?? 0;
    final day = isoDate.substring(8, 10);
    const months = [
      '',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final monthName = (month >= 1 && month <= 12) ? months[month] : '';
    return '$day $monthName $year'.trim();
  }
}

/// Compact parsed record emitted by the background isolate for SQLite insertion.
@immutable
class ParsedInstrumentRow {
  const ParsedInstrumentRow({
    required this.instrument,
    required this.tradingsymbolLower,
    required this.searchTokens,
  });

  final Instrument instrument;
  final String tradingsymbolLower;
  final String searchTokens;
}

/// Result returned by [parseInstrumentsFileInIsolate].
@immutable
class ParsedInstrumentsPayload {
  const ParsedInstrumentsPayload({
    required this.sha256,
    required this.unchanged,
    required this.rows,
  });

  final String sha256;
  final bool unchanged;
  final List<ParsedInstrumentRow> rows;
}

/// Decompresses (if gzipped), validates, and parses the Kite `/instruments`
/// CSV file inside a background [Isolate] so the UI thread never drops frames.
Future<ParsedInstrumentsPayload> parseInstrumentsFileInIsolate({
  required String filePath,
  String? previousSha256,
}) {
  return Isolate.run(
    () => _parseInstrumentsSync(filePath, previousSha256),
  );
}

ParsedInstrumentsPayload _parseInstrumentsSync(
  String filePath,
  String? previousSha256,
) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw const FormatException('Downloaded instruments file is missing.');
  }

  final rawBytes = file.readAsBytesSync();
  if (rawBytes.isEmpty) {
    throw const FormatException('Downloaded instruments file is empty.');
  }

  final digest = sha256.convert(rawBytes).toString();
  if (previousSha256 != null &&
      previousSha256.isNotEmpty &&
      digest == previousSha256) {
    return ParsedInstrumentsPayload(
      sha256: digest,
      unchanged: true,
      rows: const [],
    );
  }

  // Detect gzip magic header (0x1F 0x8B) in case HttpClient didn't auto-gunzip.
  final bool isGzipped =
      rawBytes.length >= 2 && rawBytes[0] == 0x1F && rawBytes[1] == 0x8B;
  final List<int> csvBytes = isGzipped ? gzip.decode(rawBytes) : rawBytes;
  final String csv = utf8.decode(csvBytes, allowMalformed: true);

  final rows = <ParsedInstrumentRow>[];
  final fields = <String>[];
  final fieldBuffer = StringBuffer();

  bool inQuotes = false;
  bool isHeaderRow = true;
  bool headerValidated = false;

  void flushRow() {
    if (fields.isEmpty && fieldBuffer.isEmpty) {
      return;
    }
    fields.add(fieldBuffer.toString());
    fieldBuffer.clear();

    if (isHeaderRow) {
      isHeaderRow = false;
      final firstCol = fields.first.trim().replaceAll('\uFEFF', '');
      if (firstCol != 'instrument_token' || fields.length < 12) {
        throw const FormatException(
          'Invalid instruments CSV header received from server.',
        );
      }
      headerValidated = true;
      fields.clear();
      return;
    }

    if (fields.length >= 12) {
      final token = int.tryParse(fields[0]);
      if (token != null && token > 0) {
        final exchangeToken = int.tryParse(fields[1]) ?? 0;
        final tradingsymbol = fields[2].trim();
        final name = fields[3].trim();
        final lastPrice = double.tryParse(fields[4]) ?? 0.0;
        final expiry = fields[5].trim();
        final strike = double.tryParse(fields[6]) ?? 0.0;
        final tickSize = double.tryParse(fields[7]) ?? 0.05;
        final lotSize = int.tryParse(fields[8]) ?? 1;
        final instrumentType = fields[9].trim();
        final segment = fields[10].trim();
        final exchange = fields[11].trim();

        final priorityTier = _computePriorityTier(
          segment: segment,
          exchange: exchange,
          instrumentType: instrumentType,
          expiry: expiry,
        );

        final symbolLower = tradingsymbol.toLowerCase();
        final searchTokens = _buildSearchTokens(
          symbolLower: symbolLower,
          name: name,
          expiry: expiry,
          strike: strike,
          instrumentType: instrumentType,
          segment: segment,
          exchange: exchange,
        );

        rows.add(
          ParsedInstrumentRow(
            instrument: Instrument(
              instrumentToken: token,
              exchangeToken: exchangeToken,
              tradingsymbol: tradingsymbol,
              name: name,
              lastPrice: lastPrice,
              expiry: expiry,
              strike: strike,
              tickSize: tickSize,
              lotSize: lotSize,
              instrumentType: instrumentType,
              segment: segment,
              exchange: exchange,
              priorityTier: priorityTier,
            ),
            tradingsymbolLower: symbolLower,
            searchTokens: searchTokens,
          ),
        );
      }
    }
    fields.clear();
  }

  final int len = csv.length;
  for (int i = 0; i < len; i++) {
    final int cu = csv.codeUnitAt(i);
    if (inQuotes) {
      if (cu == 0x22) {
        // '"' — check for escaped '""'
        if (i + 1 < len && csv.codeUnitAt(i + 1) == 0x22) {
          fieldBuffer.writeCharCode(0x22);
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        fieldBuffer.writeCharCode(cu);
      }
    } else {
      if (cu == 0x22) {
        inQuotes = true;
      } else if (cu == 0x2C) {
        // ','
        fields.add(fieldBuffer.toString());
        fieldBuffer.clear();
      } else if (cu == 0x0A) {
        // '\n'
        flushRow();
      } else if (cu == 0x0D) {
        // '\r' — ignore, handled on '\n' or trailing flush
        if (i + 1 >= len || csv.codeUnitAt(i + 1) != 0x0A) {
          flushRow();
        }
      } else {
        fieldBuffer.writeCharCode(cu);
      }
    }
  }
  flushRow();

  if (!headerValidated || rows.length < 50) {
    throw FormatException(
      'Incomplete instruments dump (${rows.length} rows parsed).',
    );
  }

  return ParsedInstrumentsPayload(
    sha256: digest,
    unchanged: false,
    rows: rows,
  );
}

int _computePriorityTier({
  required String segment,
  required String exchange,
  required String instrumentType,
  required String expiry,
}) {
  if (segment == 'INDICES') return 0;
  if (exchange == 'NSE' && instrumentType == 'EQ') return 1;
  if (exchange == 'BSE' && instrumentType == 'EQ') return 2;
  if (expiry.isEmpty) return 3;
  if (instrumentType == 'FUT') return 4;
  return 5;
}

String _buildSearchTokens({
  required String symbolLower,
  required String name,
  required String expiry,
  required double strike,
  required String instrumentType,
  required String segment,
  required String exchange,
}) {
  final sb = StringBuffer(symbolLower);

  // Compact alphanumeric-only alias (e.g. "m&m" -> "mm", "bajaj-auto" -> "bajajauto")
  // plus split alpha/digit transitions (e.g. "nifty26nov24500ce" -> "nifty 26 nov 24500 ce").
  final compact = StringBuffer();
  final split = StringBuffer();
  int prevKind = 0; // 0: other, 1: alpha, 2: digit
  for (int i = 0; i < symbolLower.length; i++) {
    final int c = symbolLower.codeUnitAt(i);
    final bool isAlpha = c >= 0x61 && c <= 0x7A;
    final bool isDigit = c >= 0x30 && c <= 0x39;
    if (isAlpha || isDigit) {
      compact.writeCharCode(c);
      final int kind = isAlpha ? 1 : 2;
      if (prevKind != 0 && prevKind != kind) {
        split.writeCharCode(0x20);
      }
      split.writeCharCode(c);
      prevKind = kind;
    } else {
      if (prevKind != 0) {
        split.writeCharCode(0x20);
      }
      prevKind = 0;
    }
  }

  final compactStr = compact.toString();
  if (compactStr != symbolLower && compactStr.isNotEmpty) {
    sb
      ..write(' ')
      ..write(compactStr);
  }
  final splitStr = split.toString();
  if (splitStr != symbolLower && splitStr.isNotEmpty) {
    sb
      ..write(' ')
      ..write(splitStr);
  }

  if (name.isNotEmpty) {
    sb
      ..write(' ')
      ..write(name.toLowerCase());
  }

  if (strike > 0) {
    final strikeStr = strike == strike.truncateToDouble()
        ? strike.toInt().toString()
        : strike.toString();
    sb
      ..write(' ')
      ..write(strikeStr);
  }

  if (expiry.length >= 10) {
    final month = int.tryParse(expiry.substring(5, 7)) ?? 0;
    const monthsLower = [
      '',
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    if (month >= 1 && month <= 12) {
      sb
        ..write(' ')
        ..write(monthsLower[month])
        ..write(' ')
        ..write(expiry.substring(0, 4))
        ..write(' ')
        ..write(expiry.substring(8, 10));
    }
  }

  if (instrumentType.isNotEmpty) {
    sb
      ..write(' ')
      ..write(instrumentType.toLowerCase());
  }
  if (exchange.isNotEmpty) {
    sb
      ..write(' ')
      ..write(exchange.toLowerCase());
  }
  if (segment.isNotEmpty) {
    sb
      ..write(' ')
      ..write(segment.toLowerCase());
  }

  return sb.toString();
}
