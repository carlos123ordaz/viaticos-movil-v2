import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/user_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserService _userService;
  final StorageService _storage;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;
  String? _taskId;

  AuthProvider(this._authService, this._userService, this._storage);

  String? _taskName;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  String? get taskId => _taskId;
  String? get taskName => _taskName;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> initialize() async {
    final token = _storage.accessToken;
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    _user = _storage.user;
    _taskId = _storage.taskId;
    _taskName = _storage.taskName;
    _status = AuthStatus.authenticated;
    notifyListeners();
    try {
      _user = await _userService.getMe();
      await _storage.saveUser(_user!);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.login(email, password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithMicrosoft() async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.microsoftLogin();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _taskId = null;
    _taskName = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      _user = await _userService.getMe();
      await _storage.saveUser(_user!);
      notifyListeners();
    } catch (_) {}
  }

  void setTask(String? id, String? name) {
    _taskId = id;
    _taskName = name;
    _storage.setTaskId(id);
    _storage.setTaskName(name);
    notifyListeners();
  }

  void setTaskId(String? id) {
    _taskId = id;
    if (id == null) _taskName = null;
    _storage.setTaskId(id);
    if (id == null) _storage.setTaskName(null);
    notifyListeners();
  }

  String _parseError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('credentials')) {
        return 'Credenciales incorrectas';
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return 'Sin conexión a internet';
      }
    }
    return 'Error al iniciar sesión';
  }
}
