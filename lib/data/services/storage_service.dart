import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const _accessToken = 'access_token';
  static const _refreshToken = 'refresh_token';
  static const _userData = 'user_data';
  static const _taskId = 'task_id';
  static const _taskName = 'task_name';
  static const _lastAllocations = 'last_cost_center_allocations';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String? get accessToken => _prefs.getString(_accessToken);
  String? get refreshToken => _prefs.getString(_refreshToken);
  String? get taskId => _prefs.getString(_taskId);
  String? get taskName => _prefs.getString(_taskName);

  Future<void> saveTokens(
      {required String access, required String refresh}) async {
    await _prefs.setString(_accessToken, access);
    await _prefs.setString(_refreshToken, refresh);
  }

  Future<void> saveUser(UserModel user) async {
    await _prefs.setString(_userData, jsonEncode(user.toJson()));
  }

  UserModel? get user {
    final raw = _prefs.getString(_userData);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setTaskId(String? id) async {
    if (id == null) {
      await _prefs.remove(_taskId);
    } else {
      await _prefs.setString(_taskId, id);
    }
  }

  Future<void> setTaskName(String? name) async {
    if (name == null) {
      await _prefs.remove(_taskName);
    } else {
      await _prefs.setString(_taskName, name);
    }
  }

  Future<void> saveLastAllocations(List<Map<String, dynamic>> data) async {
    await _prefs.setString(_lastAllocations, jsonEncode(data));
  }

  List<Map<String, dynamic>>? get lastAllocations {
    final raw = _prefs.getString(_lastAllocations);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_accessToken);
    await _prefs.remove(_refreshToken);
    await _prefs.remove(_userData);
    await _prefs.remove(_taskId);
    await _prefs.remove(_taskName);
  }
}
