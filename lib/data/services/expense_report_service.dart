import '../../core/constants/api_constants.dart';
import '../models/bitrix_task_model.dart';
import 'api_service.dart';
import 'bitrix_task_service.dart';

class ExpenseReportService {
  final ApiService _api;
  final BitrixTaskService _bitrix;

  ExpenseReportService(this._api, this._bitrix);

  Future<bool> getFinalizationState(String taskId) async {
    try {
      final task = await _bitrix.getTaskById(taskId);
      return task.ibFinalized;
    } catch (_) {
      return false;
    }
  }

  Future<void> finalizeReport(String taskId, String userId) async {
    await _api.post(
      ApiConstants.expenseSettlementsFinalize,
      data: {'bitrixTaskId': taskId, 'userId': userId},
    );
  }
}
