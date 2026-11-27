import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kiteconnectclient/constants/endpoints.dart';
import 'package:kiteconnectclient/services/navigation_service.dart';
import 'package:kiteconnectclient/view/auth/login_view.dart';
import 'package:material_ui/material_ui.dart';

enum HttpMethod { get, post, put, delete, patch }

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class DioClient {
  DioClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Endpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'X-Kite-Version': '3'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final requiresAuth = options.extra['requiresAuth'] as bool? ?? true;
          if (requiresAuth) {
            final accessToken = await _storage.read(key: 'access_token');
            final apiKey = dotenv.maybeGet('API_KEY');
            if (accessToken == null || accessToken.isEmpty) {
              await _handleSessionExpired();
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  message: 'Session expired. Please log in again.',
                ),
              );
              return;
            }
            if (apiKey != null && apiKey.isNotEmpty) {
              options.headers['Authorization'] = 'token $apiKey:$accessToken';
            }
          }
          debugPrint('[DIO] ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '[DIO] ${response.statusCode} ${response.requestOptions.uri}',
          );
          handler.next(response);
        },
        onError: (error, handler) async {
          debugPrint(
            '[DIO ERROR] ${error.response?.statusCode} '
            '${error.requestOptions.uri}: ${error.message}',
          );
          final requiresAuth =
              error.requestOptions.extra['requiresAuth'] as bool? ?? true;
          if (requiresAuth && _isSessionExpired(error)) {
            await _handleSessionExpired();
          }
          handler.next(error);
        },
      ),
    );
  }

  static final DioClient instance = DioClient._();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isHandlingSessionExpiry = false;

  bool _isSessionExpired(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return true;
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error_type'] == 'TokenException') {
      return true;
    }
    return false;
  }

  Future<void> _handleSessionExpired() async {
    if (_isHandlingSessionExpiry) {
      return;
    }
    _isHandlingSessionExpiry = true;
    try {
      await _storage.delete(key: 'access_token');
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginView()),
        (route) => false,
      );
    } finally {
      _isHandlingSessionExpiry = false;
    }
  }

  Future<Map<String, dynamic>> request(
    String path, {
    HttpMethod method = HttpMethod.get,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    String? contentType,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method.name.toUpperCase(),
          headers: headers,
          contentType: contentType,
          extra: {'requiresAuth': requiresAuth},
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw ApiException(
          'Request failed with status $statusCode.',
          statusCode: statusCode,
        );
      }

      final body = response.data;
      if (body == null) {
        throw ApiException(
          'Empty response from server.',
          statusCode: statusCode,
        );
      }

      if (body['status'] != null && body['status'] != 'success') {
        throw ApiException(
          (body['message'] as String?) ?? 'Request failed.',
          statusCode: statusCode,
        );
      }

      return body;
    } on DioException catch (e) {
      throw ApiException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Connection timed out. Please try again.',
      DioExceptionType.connectionError =>
        'No internet connection. Please check your network.',
      _ => e.message ?? 'Something went wrong. Please try again.',
    };
  }
}

