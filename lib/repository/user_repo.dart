import 'package:kiteconnectclient/constants/endpoints.dart';
import 'package:kiteconnectclient/model/user_profile.dart';
import 'package:kiteconnectclient/services/remote/dio.dart';

class UserRepository {
  UserRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient.instance;

  final DioClient _dioClient;

  Future<UserProfile> getProfile() async {
    final response = await _dioClient.request(
      Endpoints.userProfile,
      method: HttpMethod.get,
    );

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ApiException('Failed to load user profile.');
    }

    return UserProfile.fromJson(data);
  }
}
