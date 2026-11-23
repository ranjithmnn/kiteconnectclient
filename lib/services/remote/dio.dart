import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kiteconnectclient/constants/endpoints.dart';

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
            if (apiKey != null &&
                accessToken != null &&
                accessToken.isNotEmpty) {
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
        onError: (error, handler) {
          debugPrint(
            '[DIO ERROR] ${error.response?.statusCode} '
            '${error.requestOptions.uri}: ${error.message}',
          );
          handler.next(error);
        },
      ),
    );
  }

  static final DioClient instance = DioClient._();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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

