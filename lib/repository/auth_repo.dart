import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kiteconnectclient/constants/endpoints.dart';
import 'package:kiteconnectclient/services/remote/dio.dart';
import 'package:kiteconnectclient/utils/widgets/webview.dart';

class AuthRepository {
  AuthRepository({DioClient? dioClient, FlutterSecureStorage? storage})
    : _dioClient = dioClient ?? DioClient.instance,
      _storage = storage ?? const FlutterSecureStorage();

  final DioClient _dioClient;
  final FlutterSecureStorage _storage;

  Future<bool> login(BuildContext context) async {
    final String apiKey = (dotenv.maybeGet('API_KEY') ?? '').trim();
    final String apiSecret = (dotenv.maybeGet('API_SECRET') ?? '').trim();

    if (apiKey.isEmpty || apiSecret.isEmpty) {
      throw const ApiException(
        "Please configure API Key and API Secret in the .env file",
      );
    }

    final String? result;
    try {
      result = await WebViewBottomSheet.show(
        context,
        url: '${Endpoints.loginUrl}?v=3&api_key=$apiKey',
        onUrlChange: (url) {
          debugPrint('URL changed: $url');
        },
        shouldClose: (url) => url.startsWith(Endpoints.redirectUrl),
      );
    } on WebViewLoadException catch (e) {
      throw ApiException(e.message);
    }

    if (!context.mounted) {
      return false;
    }

    if (result == null ||
        !result.startsWith(Endpoints.redirectUrl)) {
      return false;
    }

    final uri = Uri.parse(result);
    final status = uri.queryParameters['status'];
    final requestToken = uri.queryParameters['request_token'];

    if (status != 'success' || requestToken == null || requestToken.isEmpty) {
      throw const ApiException(
        'Zerodha authentication failed. Please try again.',
      );
    }

    final String checksum = sha256
        .convert(utf8.encode('$apiKey$requestToken$apiSecret'))
        .toString();

    final response = await _dioClient.request(
      Endpoints.sessionToken,
      method: HttpMethod.post,
      data: {
        'api_key': apiKey,
        'request_token': requestToken,
        'checksum': checksum,
      },
      contentType: Headers.formUrlEncodedContentType,
      requiresAuth: false,
    );

    final data = response['data'] as Map<String, dynamic>?;
    final accessToken = data?['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(
        'Failed to retrieve access token. Please try again.',
      );
    }

    await _storage.write(key: 'access_token', value: accessToken);
    return true;
  }
}
