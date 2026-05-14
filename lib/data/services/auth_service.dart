import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api;
  final StorageService _storage;

  AuthService(this._api, this._storage);

  Future<UserModel> login(String email, String password) async {
    final response = await _api.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    await _storage.saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    final user = UserModel.fromJson(
        data['user'] as Map<String, dynamic>? ?? data);
    await _storage.saveUser(user);
    return user;
  }

  Future<UserModel> microsoftLogin() async {
    const scheme = 'corsusa';
    const redirectUri = '$scheme://auth/microsoft-callback';
    final authUrl =
        '${ApiConstants.baseUrl}${ApiConstants.loginMicrosoft}'
        '?platform=mobile'
        '&redirectUri=${Uri.encodeComponent(redirectUri)}';

    String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: scheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        throw Exception('Inicio de sesión cancelado');
      }
      rethrow;
    }

    final uri = Uri.parse(result);
    final error = uri.queryParameters['error'];
    if (error != null) {
      const messages = {
        'no_code': 'No se recibió código de autorización',
        'inactive': 'Usuario inactivo. Contacta al administrador.',
        'microsoft_auth_failed': 'Error al autenticar con Microsoft',
      };
      throw Exception(messages[error] ?? 'Error de autenticación');
    }

    final token = uri.queryParameters['token'];
    final refresh = uri.queryParameters['refresh'];
    final userParam = uri.queryParameters['user'];

    if (token == null || refresh == null) {
      throw Exception('No se recibieron las credenciales');
    }

    await _storage.saveTokens(access: token, refresh: refresh);

    final userJson = userParam != null
        ? jsonDecode(Uri.decodeComponent(userParam)) as Map<String, dynamic>
        : null;

    if (userJson == null) throw Exception('No se recibió información del usuario');

    final user = UserModel.fromJson(userJson);
    await _storage.saveUser(user);
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logout);
    } catch (_) {}
    await _storage.clear();
  }

  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    await _api.post(
      ApiConstants.changePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}
