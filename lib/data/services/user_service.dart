import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class UserService {
  final ApiService _api;

  UserService(this._api);

  Future<UserModel> getMe() async {
    final response = await _api.get(ApiConstants.userMe);
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : (response.data as Map)['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<UserModel> updateUser(
      String userId, Map<String, dynamic> body) async {
    final response = await _api.put('/users/$userId', data: body);
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : (response.data as Map)['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }
}
