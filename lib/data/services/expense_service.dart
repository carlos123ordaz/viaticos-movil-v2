import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../models/cost_center_model.dart';
import '../models/expense_model.dart';
import 'api_service.dart';

class ExpenseService {
  final ApiService _api;

  ExpenseService(this._api);

  Future<List<ExpenseModel>> getExpenses({String? taskId}) async {
    final path = taskId != null
        ? '${ApiConstants.expenses}/task/$taskId'
        : ApiConstants.expensesUnassigned;
    final response = await _api.get(path);
    final List<dynamic> list = response.data is List
        ? response.data as List
        : (response.data as Map)['data'] as List? ?? [];
    return list
        .map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseModel> getExpense(String id) async {
    final response = await _api.get('${ApiConstants.expenses}/$id');
    final data = response.data is Map
        ? response.data as Map<String, dynamic>
        : (response.data as Map)['data'] as Map<String, dynamic>;
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> createExpense(Map<String, dynamic> body) async {
    final response = await _api.post(ApiConstants.expenses, data: body);
    final data = _unwrapResponse(response.data);
    return ExpenseModel.fromJson(data);
  }

  Map<String, dynamic> _unwrapResponse(dynamic raw) {
    final Map<String, dynamic> map = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    if (map['data'] is Map) {
      return Map<String, dynamic>.from(map['data'] as Map);
    }
    return map;
  }

  Future<ExpenseModel> updateExpense(
      String id, Map<String, dynamic> body) async {
    final response = await _api.put('${ApiConstants.expenses}/$id', data: body);
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : (response.data as Map)['data'] as Map<String, dynamic>;
    return ExpenseModel.fromJson(data);
  }

  Future<void> deleteExpense(String id) async {
    await _api.delete('${ApiConstants.expenses}/$id');
  }

  Future<void> assignTaskToExpenses(List<String> expenseIds, String taskId) async {
    await _api.patch(
      '${ApiConstants.expenses}/assign-task',
      data: {'expenseIds': expenseIds, 'taskId': taskId},
    );
  }

  Future<Map<String, dynamic>> captureVoucher(String imagePath, {CancelToken? cancelToken}) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imagePath),
    });
    final response = await _api.postFormData(
      ApiConstants.expenseCapture,
      formData,
      cancelToken: cancelToken,
    );
    final raw = response.data;
    if (raw is Map<String, dynamic>) return raw;
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> voiceToExpense(String transcript) async {
    final response = await _api.post(
      ApiConstants.expenseVoice,
      data: {'transcription': transcript},
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    final raw = response.data;
    if (raw is Map<String, dynamic>) return raw;
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<ExpenseCategoryModel>> getExpenseCategories(String type) async {
    final response = await _api.get(
      ApiConstants.expenseCategories,
      params: {'type': type},
    );
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => ExpenseCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReceiptTypeModel>> getReceiptTypes() async {
    final response = await _api.get(ApiConstants.receiptTypes);
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => ReceiptTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
