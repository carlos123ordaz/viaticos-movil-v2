import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio _dio;
  final StorageService _storage;
  VoidCallback? onSessionExpired;

  ApiService(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _storage.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer ${_storage.accessToken}';
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.reject(error);
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = _storage.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.refresh}',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      await _storage.saveTokens(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String? ?? refreshToken,
      );
      return true;
    } catch (_) {
      await _storage.clear();
      onSessionExpired?.call();
      return false;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) {
    return _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data, Options? options}) {
    return _dio.post(path, data: data, options: options);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> postFormData(String path, FormData data, {CancelToken? cancelToken, Duration? receiveTimeout}) {
    return _dio.post(path,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 120),
        ));
  }

  Future<Response> putFormData(String path, FormData data) {
    return _dio.put(path,
        data: data,
        options: Options(contentType: 'multipart/form-data'));
  }
}
