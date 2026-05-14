import '../../core/constants/api_constants.dart';
import '../models/bitrix_task_model.dart';
import 'api_service.dart';

class BitrixTaskService {
  final ApiService _api;

  BitrixTaskService(this._api);

  Future<List<BitrixTaskModel>> getLastTasks() async {
    final response = await _api.get(ApiConstants.bitrixTasks, params: {'onlyMine': 'true'});
    final data = response.data;
    final List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = (data['tasks'] as List<dynamic>?)
          ?? (data['data'] as List<dynamic>?)
          ?? [];
    } else {
      list = [];
    }
    return list.map((e) => BitrixTaskModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BitrixTaskModel> getTaskById(String taskId) async {
    final response = await _api.get('${ApiConstants.bitrixTasks}/$taskId');
    return BitrixTaskModel.fromJson(response.data as Map<String, dynamic>);
  }
}
