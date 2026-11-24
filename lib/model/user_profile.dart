class UserProfile {
  final String userId;
  final String userType;
  final String email;
  final String userName;
  final String userShortname;
  final String broker;
  final List<String> exchanges;
  final List<String> products;
  final List<String> orderTypes;
  final String? avatarUrl;
  final Map<String, dynamic> meta;

  const UserProfile({
    required this.userId,
    required this.userType,
    required this.email,
    required this.userName,
    required this.userShortname,
    required this.broker,
    required this.exchanges,
    required this.products,
    required this.orderTypes,
    this.avatarUrl,
    this.meta = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String? ?? '',
      userType: json['user_type'] as String? ?? '',
      email: json['email'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      userShortname: json['user_shortname'] as String? ?? '',
      broker: json['broker'] as String? ?? '',
      exchanges: _stringList(json['exchanges']),
      products: _stringList(json['products']),
      orderTypes: _stringList(json['order_types']),
      avatarUrl: json['avatar_url'] as String?,
      meta: (json['meta'] as Map<String, dynamic>?) ?? const {},
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }
}
