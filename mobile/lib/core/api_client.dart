import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_exception.dart';
import 'token_storage.dart';

/// Cliente HTTP: base URL según plataforma, token Bearer automático
/// y mapeo de errores Dio a [ApiException].
class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient({required this.tokenStorage, String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? defaultBaseUrl(),
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.leer();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// El emulador Android expone el localhost del host como 10.0.2.2.
  /// Para dispositivo físico: --dart-define=API_BASE_URL=http://IP-DE-TU-PC:8000
  static String defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _ejecutar(() => dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _ejecutar(() => dio.post<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _ejecutar(() => dio.patch<dynamic>(path, data: body));

  Future<dynamic> _ejecutar(
      Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _mapear(e);
    }
  }

  ApiException _mapear(DioException e) {
    final response = e.response;
    if (response != null) {
      final data = response.data;
      final detail = (data is Map && data['detail'] is String)
          ? data['detail'] as String
          : 'Error inesperado del servidor (${response.statusCode}).';
      return ApiException(detail, statusCode: response.statusCode);
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'Tiempo de espera agotado. Revisá tu conexión e intentá de nuevo.',
        );
      default:
        return const ApiException(
          'Sin conexión con el servidor. Verificá tu red e intentá de nuevo.',
        );
    }
  }
}
