// core/network/dio_api_client.dart
import 'package:dio/dio.dart';
import 'package:your_app/core/network/api_client.dart';
import 'package:your_app/core/network/api_exception.dart';

/// [ApiClient] adapter over Dio. The only file in the app that touches
/// the Dio API surface beyond provider wiring.
class DioApiClient implements ApiClient {
  DioApiClient(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) => _send('GET', path, queryParameters: queryParameters, headers: headers);

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    'POST',
    path,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
  );

  @override
  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    'PUT',
    path,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
  );

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    'DELETE',
    path,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
  );

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    'PATCH',
    path,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
  );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method, headers: headers),
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    } catch (error, stackTrace) {
      throw ApiUnknownException(
        error: error,
        stackTrace: stackTrace,
        message: '$error',
      );
    }
  }

  /// The API's `error.code`, when the body actually has that shape.
  /// Adapt to your API's error envelope.
  String? _errorCode(Object? data) {
    if (data is! Map) return null;
    final error = data['error'];
    if (error is! Map) return null;
    final code = error['code'];
    return code is String ? code : null;
  }

  ApiException _mapDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError:
        return ApiConnectionException(message: exception.message);
      case DioExceptionType.badResponse:
        return ApiResponseException(
          statusCode: exception.response?.statusCode,
          data: exception.response?.data,
          message: exception.message,
          code: _errorCode(exception.response?.data),
        );
      case DioExceptionType.badCertificate ||
          DioExceptionType.cancel ||
          DioExceptionType.unknown:
        return ApiUnknownException(
          error: exception.error,
          stackTrace: exception.stackTrace,
          message: exception.message,
        );
    }
  }
}
