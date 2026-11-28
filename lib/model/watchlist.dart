import 'package:meta/meta.dart';

/// A user-created watchlist holding tradable or index instruments.
@immutable
class Watchlist {
  const Watchlist({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAtMs,
    this.itemCount = 0,
  });

  final int id;
  final String name;
  final int sortOrder;
  final int createdAtMs;
  final int itemCount;

  Watchlist copyWith({
    int? id,
    String? name,
    int? sortOrder,
    int? createdAtMs,
    int? itemCount,
  }) {
    return Watchlist(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  factory Watchlist.fromDbMap(Map<String, Object?> map) {
    return Watchlist(
      id: (map['id'] as num).toInt(),
      name: (map['name'] as String?) ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAtMs: (map['created_at_ms'] as num?)?.toInt() ?? 0,
      itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
    );
  }
}
