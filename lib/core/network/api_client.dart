import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'api_config.dart';
import 'api_exceptions.dart';

/// Lightweight HTTP API Client with Error Handling & Retry Logic for Flutter
class MobileApiClient {
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = ApiConfig.connectTimeout;

  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String get baseUrl => ApiConfig.baseUrl;

  /// Executes an HTTP request with error handling and retry logic
  Future<dynamic> request({
    required String path,
    required String method,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    dynamic body,
    int retries = ApiConfig.maxRetries,
  }) async {
    int attempts = 0;

    while (attempts <= retries) {
      attempts++;
      try {
        final uri = Uri.parse('$baseUrl$path').replace(
          queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
        );

        final request = await _openRequest(method, uri);

        // Standard headers
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('Accept', 'application/json');
        request.headers.set('X-App-Platform', 'flutter-mobile');
        request.headers.set('X-Client-Language', 'vi-VN');

        if (_authToken != null) {
          request.headers.set('Authorization', 'Bearer $_authToken');
        }

        if (headers != null) {
          headers.forEach((k, v) => request.headers.set(k, v));
        }

        if (body != null) {
          final jsonString = jsonEncode(body);
          request.write(jsonString);
        }

        final response = await request.close().timeout(ApiConfig.receiveTimeout);
        final responseBody = await response.transform(utf8.decoder).join();
        dynamic parsedData;
        try {
          parsedData = jsonDecode(responseBody);
        } catch (_) {
          parsedData = responseBody;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return parsedData;
        }

        final exception = ApiException(
          message: 'HTTP error ${response.statusCode}',
          statusCode: response.statusCode,
          errorCode: parsedData is Map ? parsedData['errorCode'] : 'HTTP_${response.statusCode}',
          userMessage: parsedData is Map ? parsedData['userMessage'] : null,
          details: parsedData,
        );

        if (attempts <= retries && exception.isRetryable) {
          await Future.delayed(ApiConfig.retryDelay * attempts);
          continue;
        }

        throw exception;
      } on SocketException catch (e) {
        final ex = ApiException(
          message: e.message,
          statusCode: 0,
          errorCode: 'ERR_NETWORK',
        );
        if (attempts <= retries) {
          await Future.delayed(ApiConfig.retryDelay * attempts);
          continue;
        }
        throw ex;
      } on TimeoutException {
        final ex = ApiException(
          message: 'Connection timed out',
          statusCode: 408,
          errorCode: 'ERR_TIMEOUT',
        );
        if (attempts <= retries) {
          await Future.delayed(ApiConfig.retryDelay * attempts);
          continue;
        }
        throw ex;
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(
          message: e.toString(),
          errorCode: 'ERR_UNKNOWN',
        );
      }
    }
  }

  Future<HttpClientRequest> _openRequest(String method, Uri uri) {
    switch (method.toUpperCase()) {
      case 'GET':
        return _httpClient.getUrl(uri);
      case 'POST':
        return _httpClient.postUrl(uri);
      case 'PUT':
        return _httpClient.putUrl(uri);
      case 'DELETE':
        return _httpClient.deleteUrl(uri);
      case 'PATCH':
        return _httpClient.patchUrl(uri);
      default:
        return _httpClient.openUrl(method, uri);
    }
  }
}
